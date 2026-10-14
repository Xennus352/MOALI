# backend/server/app/api/v1/submissions.py
"""Census submission management: listing, detail, creation, editing, review and export."""
from __future__ import annotations

import csv
import io
import json
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, selectinload

from app.api.deps import can_review, get_current_user, get_db, is_admin, require_admin
from app.api.v1.ws import publish_event
from app.core.audit import record_audit
from app.core.notifications import create_notification
from app.db import models as m
from app.db.models import User
from app.schemas.census import ReviewRequest, SubmissionCreate, SubmissionUpdate

router = APIRouter(prefix="/submissions", tags=["submissions"])

# Allowed status transitions. Key = current status, value = statuses reachable.
TRANSITIONS: dict[str, set[str]] = {
    "pending": {"under_review", "approved", "rejected"},
    "submitted": {"under_review", "approved", "rejected"},
    "under_review": {"approved", "rejected", "returned"},
    "returned": {"submitted", "under_review", "approved", "rejected"},
    "approved": {"reopened"},
    "rejected": {"reopened"},
    "reopened": {"under_review", "approved", "rejected"},
}

# action -> resulting status
_ACTION_TARGET = {
    "submit": "submitted",
    "start_review": "under_review",
    "approve": "approved",
    "reject": "rejected",
    "return": "returned",
    "reopen": "reopened",
}


def get_default_form_version(db: Session) -> m.FormVersion | None:
    return (
        db.query(m.FormVersion)
        .filter(m.FormVersion.publication_status == "published")
        .order_by(m.FormVersion.published_at.desc(), m.FormVersion.id.desc())
        .first()
    ) or db.query(m.FormVersion).order_by(m.FormVersion.id.desc()).first()


# --------------------------------------------------------------------------
# additional (admin-authored) field answers
# --------------------------------------------------------------------------
def _field_name_index(db: Session, version_id: int) -> dict[str, m.FormField]:
    """Map field ``name`` → FormField for a form version (enabled fields only)."""
    rows = (
        db.query(m.FormField)
        .filter(m.FormField.form_version_id == version_id, m.FormField.is_enabled == True)  # noqa: E712
        .all()
    )
    return {f.name: f for f in rows}


def _write_additional_answers(
    db: Session, sub: m.Submission, data: dict | None, version_id: int
) -> None:
    """Persist admin-authored answers as typed ``FormFieldAnswer`` rows.

    Only values whose key matches an enabled field of the submission's form
    version are kept; the fixed submission columns are untouched here because
    the app segments fixed fields from ``additional_data`` on its side.
    """
    if not data:
        return
    index = _field_name_index(db, version_id)
    for name, value in data.items():
        field = index.get(name)
        if field is None or value is None or value == "":
            continue
        answer = m.FormFieldAnswer(submission_id=sub.id, form_field_id=field.id)
        if isinstance(value, bool):
            answer.answer_boolean = value
        elif isinstance(value, int):
            answer.answer_integer = value
        elif isinstance(value, float):
            answer.answer_decimal = value
        elif isinstance(value, str):
            answer.answer_text = value
        else:  # lists / dicts / anything else → structured JSON
            answer.answer_json = json.dumps(value, ensure_ascii=False)
        db.add(answer)


def _answer_value(answer: m.FormFieldAnswer):
    """Rehydrate a ``FormFieldAnswer`` row to its JSON value."""
    if answer.answer_boolean is not None:
        return answer.answer_boolean
    if answer.answer_integer is not None:
        return answer.answer_integer
    if answer.answer_decimal is not None:
        return answer.answer_decimal
    if answer.answer_date is not None:
        return answer.answer_date.isoformat()
    if answer.answer_json:
        try:
            return json.loads(answer.answer_json)
        except (TypeError, ValueError):
            return answer.answer_json
    if answer.answer_text is not None:
        return answer.answer_text
    return None


def serialize_submission(sub: m.Submission, *, detail: bool = False) -> dict:
    data = {
        "id": sub.id,
        "form_version_id": sub.form_version_id,
        "form_id": sub.form_id,
        "version_number": sub.version_number,
        "state_region_id": sub.state_region_id,
        "district_id": sub.district_id,
        "township_id": sub.township_id,
        "village_tract_id": sub.village_tract_id,
        "ward_id": sub.ward_id,
        "household_no": sub.household_no,
        "respondent_name_burmese": sub.respondent_name_burmese,
        "respondent_name_english": sub.respondent_name_english,
        "respondent_phone": sub.respondent_phone,
        "respondent_gender_id": sub.respondent_gender_id,
        "respondent_age": sub.respondent_age,
        "respondent_age_group_id": sub.respondent_age_group_id,
        "household_head_name_burmese": sub.household_head_name_burmese,
        "household_head_age": sub.household_head_age,
        "household_head_phone": sub.household_head_phone,
        "interview_date": sub.interview_date.isoformat() if sub.interview_date else None,
        "has_raised_animals": sub.has_raised_animals,
        "has_poultry": sub.has_poultry,
        "collection_status": sub.collection_status,
        "review_status": sub.review_status,
        "review_notes": sub.review_notes,
        "reviewed_by": sub.reviewed_by,
        "reviewed_at": sub.reviewed_at.isoformat() if sub.reviewed_at else None,
        "created_by_user_id": sub.created_by_user_id,
        "created_at": sub.created_at.isoformat() if sub.created_at else None,
        "updated_at": sub.updated_at.isoformat() if sub.updated_at else None,
        # Denormalised geography names (cheap: relationships are joined eagerly).
        "state_region_burmese": sub.state_region.burmese_name if sub.state_region else None,
        "state_region_english": sub.state_region.english_name if sub.state_region else None,
        "district_burmese": sub.district.burmese_name if sub.district else None,
        "township_burmese": sub.township.burmese_name if sub.township else None,
        "village_tract_burmese": sub.village_tract.burmese_name if sub.village_tract else None,
        "ward_burmese": sub.ward.burmese_name if sub.ward else None,
    }
    if detail:
        data.update({
            "respondent_gender": sub.respondent_gender.burmese_name if sub.respondent_gender else None,
            "respondent_age_group": sub.respondent_age_group.burmese_name if sub.respondent_age_group else None,
            "respondent_education": sub.respondent_education,
            "household_head_gender_id": sub.household_head_gender_id,
            "household_head_gender": sub.household_head_gender.burmese_name if sub.household_head_gender else None,
            "household_head_age_group_id": sub.household_head_age_group_id,
            "household_head_age_group": sub.household_head_age_group.burmese_name if sub.household_head_age_group else None,
            "household_head_education": sub.household_head_education,
            "interviewer_name": sub.interviewer_name,
            "interviewer_phone": sub.interviewer_phone,
            "animal_counts": [
                {
                    "id": ac.id,
                    "animal_type_id": ac.animal_type_id,
                    "animal_type": ac.animal_type.burmese_name if ac.animal_type else None,
                    "animal_type_code": ac.animal_type.code if ac.animal_type else None,
                    "species_id": ac.species_id,
                    "species": ac.species.burmese_name if ac.species else None,
                    "breed_id": ac.breed_id,
                    "breed": ac.breed.burmese_name if ac.breed else None,
                    "age_group_id": ac.age_group_id,
                    "age_group": ac.age_group.burmese_name if ac.age_group else None,
                    "gender": ac.gender,
                    "count": ac.count,
                }
                for ac in sub.animal_counts
            ],
            "breeding_counts": [
                {
                    "id": bc.id,
                    "breeding_category_id": bc.breeding_category_id,
                    "breeding_category": bc.breeding_category.burmese_name if bc.breeding_category else None,
                    "male_count": bc.male_count,
                    "female_count": bc.female_count,
                }
                for bc in sub.breeding_counts
            ],
            "animal_total": sum(ac.count for ac in sub.animal_counts if not ac.is_total),
            "additional_data": {
                ans.form_field.name: _answer_value(ans)
                for ans in sub.form_field_answers
                if ans.form_field is not None
            },
        })
    return data


# --------------------------------------------------------------------------
# list / detail
# --------------------------------------------------------------------------
@router.get("")
def list_submissions(
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=200),
    q: str | None = Query(None, description="Search household no / respondent / interviewer"),
    state_region_id: int | None = None,
    district_id: int | None = None,
    township_id: int | None = None,
    status_filter: str | None = Query(None, alias="status"),
    date_from: date | None = None,
    date_to: date | None = None,
    mine: bool = Query(False, description="Only the caller's own submissions."),
    sort: str = Query("created_at", pattern="^(created_at|updated_at|interview_date|household_no|id)$"),
    order: str = Query("desc", pattern="^(asc|desc)$"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = db.query(m.Submission).options(
        selectinload(m.Submission.state_region),
        selectinload(m.Submission.district),
        selectinload(m.Submission.township),
    )
    # Data isolation: enumerators (and any non reviewer/admin role) only ever see
    # their own records. Reviewers and admins see everything, and may narrow the
    # view to their own submissions with ``mine=true``.
    if not (is_admin(user) or can_review(user)) or mine:
        query = query.filter(m.Submission.created_by_user_id == user.id)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(
            m.Submission.household_no.ilike(like),
            m.Submission.respondent_name_burmese.ilike(like),
            m.Submission.respondent_name_english.ilike(like),
            m.Submission.interviewer_name.ilike(like),
        ))
    if state_region_id:
        query = query.filter(m.Submission.state_region_id == state_region_id)
    if district_id:
        query = query.filter(m.Submission.district_id == district_id)
    if township_id:
        query = query.filter(m.Submission.township_id == township_id)
    if status_filter:
        query = query.filter(m.Submission.collection_status == status_filter)
    if date_from:
        query = query.filter(m.Submission.interview_date >= date_from)
    if date_to:
        query = query.filter(m.Submission.interview_date <= date_to)

    total = query.count()
    sort_col = getattr(m.Submission, sort)
    query = query.order_by(sort_col.asc() if order == "asc" else sort_col.desc())
    rows = query.offset((page - 1) * page_size).limit(page_size).all()

    return {
        "items": [serialize_submission(r) for r in rows],
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": max(1, (total + page_size - 1) // page_size),
    }


@router.get("/export.csv")
def export_submissions_csv(
    q: str | None = None,
    state_region_id: int | None = None,
    status_filter: str | None = Query(None, alias="status"),
    date_from: date | None = None,
    date_to: date | None = None,
    mine: bool = Query(False),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Export the currently filtered submissions as CSV (capped at 20k rows).

    Non-privileged users only ever export their own records.
    """
    query = db.query(m.Submission)
    if not (is_admin(user) or can_review(user)) or mine:
        query = query.filter(m.Submission.created_by_user_id == user.id)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(
            m.Submission.household_no.ilike(like),
            m.Submission.respondent_name_burmese.ilike(like),
        ))
    if state_region_id:
        query = query.filter(m.Submission.state_region_id == state_region_id)
    if status_filter:
        query = query.filter(m.Submission.collection_status == status_filter)
    if date_from:
        query = query.filter(m.Submission.interview_date >= date_from)
    if date_to:
        query = query.filter(m.Submission.interview_date <= date_to)

    rows = query.order_by(m.Submission.id.desc()).limit(20000).all()

    # Aggregate admin-authored answers (extra fields) per submission so the
    # export surface matches the live form definition without a schema change.
    answer_index: dict[int, dict[str, object]] = {}
    if rows:
        fa_rows = (
            db.query(m.FormFieldAnswer)
            .filter(m.FormFieldAnswer.submission_id.in_([r.id for r in rows]))
            .all()
        )
        for fa in fa_rows:
            if fa.form_field is None:
                continue
            answer_index.setdefault(fa.submission_id, {})[fa.form_field.name] = _answer_value(fa)

    def safe(value) -> str:
        text = "" if value is None else str(value)
        # Prevent CSV / spreadsheet formula injection.
        if text[:1] in ("=", "+", "-", "@", "\t", "\r"):
            text = "'" + text
        return text

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow([
        "id", "household_no", "respondent", "respondent_age", "household_head_age",
        "interview_date", "state_region", "district", "township", "status", "review_status",
        "additional_data",
    ])
    for r in rows:
        writer.writerow([
            r.id, safe(r.household_no), safe(r.respondent_name_burmese),
            r.respondent_age if r.respondent_age is not None else "",
            r.household_head_age if r.household_head_age is not None else "",
            r.interview_date.isoformat() if r.interview_date else "",
            safe(r.state_region.burmese_name if r.state_region else ""),
            safe(r.district.burmese_name if r.district else ""),
            safe(r.township.burmese_name if r.township else ""),
            safe(r.collection_status), safe(r.review_status),
            safe(json.dumps(answer_index.get(r.id, {}), ensure_ascii=False)) if answer_index.get(r.id) else "",
        ])
    record_audit(db, action="submissions.export", entity_type="submission",
                 actor_id=user.id, metadata={"rows": len(rows)}, commit=True)
    return Response(
        content=buffer.getvalue().encode("utf-8-sig"),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="submissions.csv"'},
    )


@router.get("/{submission_id}")
def get_submission(
    submission_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sub = (
        db.query(m.Submission)
        .options(
            selectinload(m.Submission.animal_counts).selectinload(m.AnimalCount.animal_type),
            selectinload(m.Submission.animal_counts).selectinload(m.AnimalCount.species),
            selectinload(m.Submission.animal_counts).selectinload(m.AnimalCount.breed),
            selectinload(m.Submission.animal_counts).selectinload(m.AnimalCount.age_group),
            selectinload(m.Submission.breeding_counts).selectinload(m.BreedingCount.breeding_category),
            selectinload(m.Submission.state_region),
            selectinload(m.Submission.district),
            selectinload(m.Submission.township),
            selectinload(m.Submission.village_tract),
            selectinload(m.Submission.ward),
            selectinload(m.Submission.respondent_gender),
            selectinload(m.Submission.respondent_age_group),
            selectinload(m.Submission.household_head_gender),
            selectinload(m.Submission.household_head_age_group),
        )
        .filter(m.Submission.id == submission_id)
        .first()
    )
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found")
    # Data isolation: enumerators may only open their own records. Reviewers and
    # admins may open any record. Return 404 (not 403) so the existence of other
    # users' submissions is not disclosed.
    if not (is_admin(user) or can_review(user)) and sub.created_by_user_id != user.id:
        raise HTTPException(status_code=404, detail="Submission not found")

    history = (
        db.query(m.AuditLog)
        .filter(m.AuditLog.entity_type == "submission", m.AuditLog.entity_id == submission_id)
        .order_by(m.AuditLog.created_at.desc())
        .limit(50)
        .all()
    )
    result = serialize_submission(sub, detail=True)
    result["review_history"] = [
        {
            "id": h.id,
            "actor_id": h.actor_id,
            "action": h.action,
            "metadata": h.metadata,
            "created_at": h.created_at.isoformat() if h.created_at else None,
        }
        for h in history
    ]
    return result


# --------------------------------------------------------------------------
# create / update
# --------------------------------------------------------------------------
@router.post("", status_code=status.HTTP_201_CREATED)
def create_submission(
    payload: SubmissionCreate,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    form_version = None
    if payload.form_version_id:
        form_version = db.get(m.FormVersion, payload.form_version_id)
        if not form_version:
            raise HTTPException(status_code=422, detail="form_version_id does not exist")
    else:
        form_version = get_default_form_version(db)
    if not form_version:
        raise HTTPException(
            status_code=409,
            detail="No census form has been published yet. An administrator must publish a form first.",
        )

    # Duplicate protection (same household + township + interview date + version).
    if not payload.allow_duplicate:
        dup = (
            db.query(m.Submission)
            .filter(
                m.Submission.household_no == payload.household_no,
                m.Submission.township_id == payload.township_id,
                m.Submission.interview_date == payload.interview_date,
                m.Submission.form_version_id == form_version.id,
                m.Submission.collection_status != "rejected",
            )
            .first()
        )
        if dup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"A submission for household {payload.household_no} on "
                    f"{payload.interview_date} already exists (id={dup.id}). "
                    "Set allow_duplicate=true to record an intentional re-survey."
                ),
            )

    # Validate foreign keys referenced by the payload.
    _validate_geo(db, payload.state_region_id, payload.district_id, payload.township_id,
                  payload.village_tract_id, payload.ward_id)

    values = payload.model_dump(exclude={"animal_counts", "breeding_counts", "allow_duplicate", "form_version_id", "additional_data"})
    sub = m.Submission(
        **values,
        form_version_id=form_version.id,
        form_id=form_version.form_id,
        version_number=form_version.version_number,
        collection_status="submitted",
        review_status="pending",
        created_by_user_id=user.id,
    )
    db.add(sub)
    db.flush()  # assign sub.id

    for idx, ac in enumerate(payload.animal_counts):
        if ac.count < 0:
            raise HTTPException(status_code=422, detail="Animal counts cannot be negative")
        db.add(m.AnimalCount(
            submission_id=sub.id, animal_type_id=ac.animal_type_id, breed_id=ac.breed_id,
            species_id=ac.species_id, age_group_id=ac.age_group_id, gender=ac.gender,
            count=ac.count, display_order=idx,
        ))
    for bc in payload.breeding_counts:
        db.add(m.BreedingCount(
            submission_id=sub.id, breeding_category_id=bc.breeding_category_id,
            male_count=bc.male_count, female_count=bc.female_count,
        ))
    _write_additional_answers(db, sub, payload.additional_data, form_version.id)

    record_audit(db, action="submission.create", entity_type="submission", entity_id=sub.id,
                 actor_id=user.id, after={"household_no": sub.household_no}, request=request)
    create_notification(
        db,
        title_burmese="တင်သွင်းမှု အသစ် ရောက်ရှိပါသည်",
        title_english="New submission received",
        message_burmese=(
            f"အိမ်ထောင်စုအမှတ် {sub.household_no} မှ တင်သွင်းမှု #{sub.id} ကို "
            f"လက်ခံရရှိပါသည်။"
        ),
        message_english=f"Submission #{sub.id} from household {sub.household_no} was received.",
        type="submission",
        related_entity_type="submission",
        related_entity_id=sub.id,
        recipient_role="admin",
        created_by=user.email,
    )
    db.commit()
    db.refresh(sub)
    # Real-time: admins/reviewers see the new submission appear live; the
    # enumerator who submitted it gets a confirmation of the recorded record.
    publish_event("submission.created", {
        "id": sub.id,
        "household_no": sub.household_no,
        "state_region_id": sub.state_region_id,
        "township_id": sub.township_id,
        "collection_status": sub.collection_status,
        "created_by_user_id": user.id,
    }, roles=["admin", "reviewer"], user_ids=[user.id])
    return serialize_submission(sub, detail=True)


@router.patch("/{submission_id}")
def update_submission(
    submission_id: int,
    payload: SubmissionUpdate,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sub = db.get(m.Submission, submission_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found")

    # Only admins/reviewers may edit arbitrary records; creators may edit their
    # own submissions while still pending or returned for correction.
    is_owner = sub.created_by_user_id == user.id
    editable_status = sub.collection_status in {"pending", "returned", "submitted", "draft"}
    if not (is_admin(user) or can_review(user) or (is_owner and editable_status)):
        raise HTTPException(status_code=403, detail="You may not edit this submission")

    before = {"household_no": sub.household_no, "collection_status": sub.collection_status}
    data = payload.model_dump(exclude_unset=True, exclude={"animal_counts", "breeding_counts", "additional_data"})
    for key, value in data.items():
        setattr(sub, key, value)

    if payload.animal_counts is not None:
        db.query(m.AnimalCount).filter(m.AnimalCount.submission_id == sub.id).delete()
        for idx, ac in enumerate(payload.animal_counts):
            db.add(m.AnimalCount(
                submission_id=sub.id, animal_type_id=ac.animal_type_id, breed_id=ac.breed_id,
                species_id=ac.species_id, age_group_id=ac.age_group_id, gender=ac.gender,
                count=ac.count, display_order=idx,
            ))
    if payload.breeding_counts is not None:
        db.query(m.BreedingCount).filter(m.BreedingCount.submission_id == sub.id).delete()
        for bc in payload.breeding_counts:
            db.add(m.BreedingCount(
                submission_id=sub.id, breeding_category_id=bc.breeding_category_id,
                male_count=bc.male_count, female_count=bc.female_count,
            ))
    if payload.additional_data is not None:
        db.query(m.FormFieldAnswer).filter(m.FormFieldAnswer.submission_id == sub.id).delete()
        _write_additional_answers(db, sub, payload.additional_data, sub.form_version_id)

    record_audit(db, action="submission.update", entity_type="submission", entity_id=sub.id,
                 actor_id=user.id, before=before, after={"household_no": sub.household_no},
                 request=request)
    db.commit()
    db.refresh(sub)
    return serialize_submission(sub, detail=True)


# --------------------------------------------------------------------------
# review workflow
# --------------------------------------------------------------------------
@router.post("/{submission_id}/review")
def review_submission(
    submission_id: int,
    payload: ReviewRequest,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sub = db.get(m.Submission, submission_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found")

    target = _ACTION_TARGET[payload.action]

    # Enumerators may only submit their own drafts/resubmissions.
    if payload.action in {"submit"}:
        if not (is_admin(user) or sub.created_by_user_id == user.id):
            raise HTTPException(status_code=403, detail="You may not submit this record")
    elif not can_review(user):
        raise HTTPException(status_code=403, detail="Reviewer permission required")

    if payload.action == "reject" and not (payload.notes or "").strip():
        raise HTTPException(status_code=422, detail="A reason is required when rejecting a submission")

    allowed = TRANSITIONS.get(sub.collection_status, set())
    if target not in allowed:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot move submission from '{sub.collection_status}' to '{target}'",
        )

    before = {"collection_status": sub.collection_status, "review_status": sub.review_status}
    sub.collection_status = target
    sub.review_status = {
        "approved": "approved", "rejected": "rejected", "returned": "returned",
    }.get(target, "pending" if target in {"submitted", "under_review", "reopened"} else sub.review_status)
    if payload.notes is not None:
        sub.review_notes = payload.notes
    if target in {"approved", "rejected", "returned"}:
        sub.reviewed_by = user.email
        sub.reviewed_at = datetime.utcnow()

    record_audit(
        db, action=f"submission.{payload.action}", entity_type="submission", entity_id=sub.id,
        actor_id=user.id, before=before,
        after={"collection_status": sub.collection_status, "review_status": sub.review_status},
        metadata={"notes": payload.notes} if payload.notes else None, request=request,
    )
    status_label_en = {
        "submitted": "Submitted", "under_review": "Under review", "approved": "Approved",
        "rejected": "Rejected", "returned": "Returned", "reopened": "Reopened",
    }.get(target, target)
    status_label_my = {
        "submitted": "တင်သွင်းပြီး", "under_review": "စစ်ဆေးနေဆဲ", "approved": "အတည်ပြုပြီး",
        "rejected": "ပယ်ချပြီး", "returned": "ပြန်လွှဲပြီး", "reopened": "ပြန်ဖွင့်ပြီး",
    }.get(target, target)
    create_notification(
        db,
        title_burmese="သင့်တင်သွင်းမှု အခြေအနေ ပြောင်းလဲပါပြီ",
        title_english="Your submission was reviewed",
        message_burmese=(
            f"တင်သွင်းမှု #{sub.id} (အိမ်ထောင်စု {sub.household_no}) ကို "
            f"“{status_label_my}” အဖြစ် သတ်မှတ်ပါပြီ။"
        ),
        message_english=(
            f"Submission #{sub.id} (household {sub.household_no}) was marked "
            f"“{status_label_en}”."
        ),
        type="review",
        related_entity_type="submission",
        related_entity_id=sub.id,
        recipient_role="enumerator",
        created_by=user.email,
    )
    db.commit()
    db.refresh(sub)
    # Real-time: the review queue and dashboard status charts update live,
    # and the submitting enumerator is notified about their submission.
    publish_event("submission.status_changed", {
        "id": sub.id,
        "household_no": sub.household_no,
        "action": payload.action,
        "collection_status": sub.collection_status,
        "review_status": sub.review_status,
    }, roles=["admin", "reviewer"], user_ids=[sub.created_by_user_id] if sub.created_by_user_id else None)
    return serialize_submission(sub, detail=True)


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def _validate_geo(db: Session, *ids: int | None) -> None:
    """Ensure each provided geographic id exists and the hierarchy is coherent."""
    checks = [
        (m.StateRegion, ids[0], "state_region_id"),
        (m.District, ids[1], "district_id"),
        (m.Township, ids[2], "township_id"),
        (m.VillageTract, ids[3], "village_tract_id"),
        (m.Ward, ids[4], "ward_id"),
    ]
    for model, value, name in checks:
        if value is not None and db.get(model, value) is None:
            raise HTTPException(status_code=422, detail=f"{name}={value} does not exist")
