# backend/server/app/api/v1/forms.py
"""Census form definitions, sections, fields and publication."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user, get_db, require_admin
from app.core.audit import record_audit
from app.db import models as m
from app.db.models import User

router = APIRouter(prefix="/forms", tags=["forms"])


class SectionIn(BaseModel):
    title_burmese: str
    title_english: str | None = None
    description_burmese: str | None = None
    description_english: str | None = None
    display_order: int = 0
    is_enabled: bool = True
    is_conditional: bool = False
    condition_json: str | None = None
    navigation_order: str = "sequential"


class FieldIn(BaseModel):
    name: str
    title_burmese: str
    title_english: str | None = None
    field_type: str
    is_required: bool = False
    is_enabled: bool = True
    display_order: int = 0
    associated_section_id: int | None = None
    option_source: str = "static"
    data_binding: str | None = None
    condition_json: str | None = None
    placeholder_burmese: str | None = None
    placeholder_english: str | None = None
    min_length: int | None = None
    max_length: int | None = None
    min_value: int | None = None
    max_value: int | None = None
    default_value: str | None = None
    unit: str | None = None


class FormCreate(BaseModel):
    form_id: str = Field(..., max_length=50)
    burmese_title: str
    english_title: str | None = None
    description: str | None = None


class FormClone(BaseModel):
    """Parameters for duplicating an existing form into a new editable draft."""

    form_id: str = Field(..., max_length=50)
    burmese_title: str | None = None
    english_title: str | None = None


def _serialize_form(form: m.Form) -> dict:
    version = (
        sorted(form.form_versions, key=lambda v: v.version_number, reverse=True)[0]
        if form.form_versions
        else None
    )
    return {
        "id": form.id,
        "form_id": form.form_id,
        "burmese_title": form.burmese_title,
        "english_title": form.english_title,
        "description": form.description,
        "publication_status": form.publication_status,
        "version_number": form.version_number,
        "created_at": form.created_at.isoformat() if form.created_at else None,
        "form_version_id": version.id if version else None,
        "form_sections": [
            {
                "id": s.id,
                "title_burmese": s.title_burmese,
                "title_english": s.title_english,
                "description_burmese": s.description_burmese,
                "description_english": s.description_english,
                "display_order": s.display_order,
                "is_enabled": s.is_enabled,
                "is_conditional": s.is_conditional,
                "condition_json": s.condition_json,
                "navigation_order": s.navigation_order,
            }
            for s in (version.form_sections if version else [])
        ],
        "form_fields": [
            {
                "id": f.id,
                "name": f.name,
                "title_burmese": f.title_burmese,
                "title_english": f.title_english,
                "field_type": f.field_type,
                "is_required": f.is_required,
                "is_enabled": f.is_enabled,
                "display_order": f.display_order,
                "associated_section_id": f.associated_section_id,
                "option_source": f.option_source,
                "data_binding": f.data_binding,
                "placeholder_burmese": f.placeholder_burmese,
                "unit": f.unit,
                "min_value": f.min_value,
                "max_value": f.max_value,
                "default_value": f.default_value,
            }
            for f in (version.form_fields if version else [])
        ],
    }


@router.get("")
def list_forms(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    forms = (
        db.query(m.Form)
        .options(selectinload(m.Form.form_versions).selectinload(m.FormVersion.form_sections),
                 selectinload(m.Form.form_versions).selectinload(m.FormVersion.form_fields))
        .order_by(m.Form.id)
        .all()
    )
    return [_serialize_form(f) for f in forms]


@router.get("/published")
def get_published_form(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    form = db.query(m.Form).filter(m.Form.is_published == True).first()  # noqa: E712
    if not form:
        form = db.query(m.Form).order_by(m.Form.id).first()
    if not form:
        raise HTTPException(status_code=404, detail="No form has been defined")
    return _serialize_form(form)


@router.get("/{form_id}")
def get_form(form_id: str, db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    form = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    return _serialize_form(form)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_form(
    payload: FormCreate,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if db.query(m.Form).filter(m.Form.form_id == payload.form_id).first():
        raise HTTPException(status_code=409, detail="A form with that form_id already exists")
    form = m.Form(
        form_id=payload.form_id,
        burmese_title=payload.burmese_title,
        english_title=payload.english_title,
        description=payload.description,
        publication_status="draft",
        is_draft=True,
        created_by=admin.email,
    )
    db.add(form)
    db.flush()
    version = m.FormVersion(
        form_id=form.id,
        version_number=1,
        definition_json=json.dumps({"sections": [], "fields": []}),
        definition_hash=hashlib.sha256(b"{}").hexdigest(),
        publication_status="draft",
        created_by=admin.email,
    )
    db.add(version)
    db.commit()
    db.refresh(form)
    record_audit(db, action="form.create", entity_type="form", entity_id=form.id,
                 actor_id=admin.id, after={"form_id": form.form_id}, request=request, commit=True)
    return _serialize_form(form)


def _latest_version(db: Session, form: m.Form) -> m.FormVersion:
    version = (
        db.query(m.FormVersion)
        .filter(m.FormVersion.form_id == form.id)
        .order_by(m.FormVersion.version_number.desc())
        .first()
    )
    if not version:
        raise HTTPException(status_code=404, detail="Form has no versions")
    return version


@router.post("/{form_id}/clone", status_code=status.HTTP_201_CREATED)
def clone_form(
    form_id: str,
    payload: FormClone,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Duplicate a form's latest version into a brand-new editable draft.

    Publishing is irreversible, so the supported way to iterate on a live form
    is to copy it. The copy starts as an editable v1 draft; the source form and
    every one of its submissions are left completely untouched.
    """
    source = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Form not found")
    if db.query(m.Form).filter(m.Form.form_id == payload.form_id).first():
        raise HTTPException(status_code=409, detail="A form with that form_id already exists")

    source_version = _latest_version(db, source)

    copy = m.Form(
        form_id=payload.form_id,
        burmese_title=payload.burmese_title or f"{source.burmese_title} (မူတူ)",
        english_title=payload.english_title
        or (f"{source.english_title} (copy)" if source.english_title else None),
        description=source.description,
        publication_status="draft",
        is_draft=True,
        is_published=False,
        created_by=admin.email,
    )
    db.add(copy)
    db.flush()

    version = m.FormVersion(
        form_id=copy.id,
        version_number=1,
        definition_json=source_version.definition_json,
        definition_hash=source_version.definition_hash,
        publication_status="draft",
        is_immutable=False,
        created_by=admin.email,
    )
    db.add(version)
    db.flush()

    # Copy sections first, remembering old → new ids so fields keep their
    # section assignment.
    section_id_map: dict[int, int] = {}
    for s in sorted(source_version.form_sections, key=lambda x: (x.display_order or 0, x.id)):
        new_section = m.FormSection(
            form_version_id=version.id,
            title_burmese=s.title_burmese,
            title_english=s.title_english,
            description_burmese=s.description_burmese,
            description_english=s.description_english,
            display_order=s.display_order,
            is_enabled=s.is_enabled,
            is_conditional=s.is_conditional,
            condition_json=s.condition_json,
            navigation_order=s.navigation_order,
        )
        db.add(new_section)
        db.flush()
        section_id_map[s.id] = new_section.id

    copied = 0
    for f in sorted(source_version.form_fields, key=lambda x: (x.display_order or 0, x.id)):
        db.add(
            m.FormField(
                form_version_id=version.id,
                title_burmese=f.title_burmese,
                title_english=f.title_english,
                field_type=f.field_type,
                name=f.name,
                placeholder_burmese=f.placeholder_burmese,
                placeholder_english=f.placeholder_english,
                is_required=f.is_required,
                is_enabled=f.is_enabled,
                is_searchable=f.is_searchable,
                is_exportable=f.is_exportable,
                is_reportable=f.is_reportable,
                is_sensitive=f.is_sensitive,
                is_filterable=f.is_filterable,
                display_order=f.display_order,
                min_length=f.min_length,
                max_length=f.max_length,
                min_value=f.min_value,
                max_value=f.max_value,
                decimal_precision=f.decimal_precision,
                default_value=f.default_value,
                unit=f.unit,
                associated_section_id=section_id_map.get(f.associated_section_id),
                condition_json=f.condition_json,
                option_source=f.option_source,
                data_binding=f.data_binding,
                is_editable_after_submission=f.is_editable_after_submission,
                calculation_formula=f.calculation_formula,
            )
        )
        copied += 1

    db.commit()
    db.refresh(copy)
    record_audit(
        db,
        action="form.clone",
        entity_type="form",
        entity_id=copy.id,
        actor_id=admin.id,
        after={"from": source.form_id, "to": copy.form_id, "fields": copied},
        request=request,
        commit=True,
    )
    return _serialize_form(copy)


@router.put("/{form_id}/sections")
def replace_sections(
    form_id: str,
    sections: list[SectionIn],
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Replace the sections of the latest draft version of a form."""
    form = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    version = _latest_version(db, form)
    if version.is_immutable:
        raise HTTPException(status_code=409, detail="Published versions are immutable; create a new version to edit")

    db.query(m.FormSection).filter(m.FormSection.form_version_id == version.id).delete()
    for s in sections:
        db.add(m.FormSection(form_version_id=version.id, **s.model_dump()))
    db.commit()
    record_audit(db, action="form.sections_update", entity_type="form", entity_id=form.id,
                 actor_id=admin.id, metadata={"count": len(sections)}, request=request, commit=True)
    return _serialize_form(form)


@router.put("/{form_id}/fields")
def replace_fields(
    form_id: str,
    fields: list[FieldIn],
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    form = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    version = _latest_version(db, form)
    if version.is_immutable:
        raise HTTPException(status_code=409, detail="Published versions are immutable; create a new version to edit")

    valid_types = {
        "short_text", "long_text", "integer", "decimal", "date", "time", "datetime",
        "telephone", "email", "single_select", "multi_select", "radio", "checkbox",
        "boolean", "number_counter", "repeating_group", "geographic", "heading", "paragraph",
    }
    db.query(m.FormField).filter(m.FormField.form_version_id == version.id).delete()
    for f in fields:
        if f.field_type not in valid_types:
            raise HTTPException(status_code=422, detail=f"Unsupported field_type '{f.field_type}'")
        db.add(m.FormField(form_version_id=version.id, **f.model_dump()))
    db.commit()
    record_audit(db, action="form.fields_update", entity_type="form", entity_id=form.id,
                 actor_id=admin.id, metadata={"count": len(fields)}, request=request, commit=True)
    return _serialize_form(form)


@router.post("/{form_id}/publish")
def publish_form(
    form_id: str,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Publish the latest version of a form, freezing it for future submissions."""
    form = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    version = _latest_version(db, form)
    if version.is_immutable:
        raise HTTPException(status_code=409, detail="This form version is already published")

    version.publication_status = "published"
    version.is_immutable = True
    version.published_by = admin.email
    version.published_at = datetime.utcnow()

    # Exactly one form drives collection at a time. Archiving the others keeps
    # ``/forms/published`` unambiguous; their versions and submissions are
    # never modified.
    db.query(m.Form).filter(
        m.Form.id != form.id, m.Form.is_published == True  # noqa: E712
    ).update(
        {
            m.Form.is_published: False,
            m.Form.publication_status: "archived",
        },
        synchronize_session=False,
    )

    form.is_published = True
    form.is_draft = False
    form.publication_status = "published"
    form.published_by = admin.email
    form.published_at = datetime.utcnow()
    db.commit()
    record_audit(db, action="form.publish", entity_type="form", entity_id=form.id,
                 actor_id=admin.id, after={"version": version.version_number}, request=request, commit=True)
    return {"detail": f"Form '{form_id}' version {version.version_number} published"}


@router.delete("/{form_id}")
def delete_form(
    form_id: str,
    request: Request,
    force: bool = False,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Delete a form and every version/section/field it owns.

    Guard rails protect live data:

    * the currently published form can never be deleted (publishing another
      form first is the supported path);
    * a form that already has submissions is refused unless ``force=true``,
      because its submissions reference the frozen version they were captured
      against.
    """
    form = db.query(m.Form).filter(m.Form.form_id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    if form.is_published:
        raise HTTPException(
            status_code=409,
            detail=(
                "This form is currently published and drives field collection. "
                "Publish a different form first, then delete this one."
            ),
        )

    version_ids = [v.id for v in form.form_versions]
    submission_count = 0
    if version_ids:
        submission_count = (
            db.query(func.count(m.Submission.id))
            .filter(m.Submission.form_version_id.in_(version_ids))
            .scalar()
            or 0
        )
    if submission_count and not force:
        raise HTTPException(
            status_code=409,
            detail=(
                f"This form has {submission_count} submission(s) tied to its "
                "versions. Pass force=true to delete it anyway (their answers "
                "would be orphaned)."
            ),
        )

    for vid in version_ids:
        db.query(m.FormField).filter(m.FormField.form_version_id == vid).delete()
        db.query(m.FormSection).filter(m.FormSection.form_version_id == vid).delete()
    if version_ids:
        db.query(m.FormVersion).filter(m.FormVersion.form_id == form.id).delete()
    db.delete(form)
    db.commit()
    record_audit(db, action="form.delete", entity_type="form", entity_id=form.id,
                 actor_id=admin.id, after={"form_id": form_id}, request=request, commit=True)
    return {"detail": f"Form '{form_id}' deleted"}
