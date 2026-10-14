# backend/server/app/api/v1/meta.py
"""Health checks, geography tree, the currently published census form and notifications."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, or_, text
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.db import models as m
from app.db.models import User

router = APIRouter(tags=["meta"])


@router.get("/health")
def health(db: Session = Depends(get_db)):
    """Liveness + readiness probe. Reports database connectivity."""
    db_ok = True
    error = None
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # pragma: no cover - only on a broken DB
        db_ok = False
        error = str(exc)
    return {
        "status": "ok" if db_ok else "degraded",
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "database": "connected" if db_ok else f"error: {error}",
    }


@router.get("/meta/geography")
def geography_tree(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    """Return the full State/Region → District → Township → Village tract → Ward tree."""
    regions = (
        db.query(m.StateRegion)
        .filter(m.StateRegion.is_active == True)  # noqa: E712
        .order_by(m.StateRegion.display_order, m.StateRegion.id)
        .all()
    )
    result = []
    for region in regions:
        districts = []
        for district in region.districts:
            if not district.is_active:
                continue
            townships = []
            for township in district.townships:
                if not township.is_active:
                    continue
                tracts = []
                for tract in township.village_tracts:
                    if not tract.is_active:
                        continue
                    tracts.append({
                        "id": tract.id,
                        "burmese_name": tract.burmese_name,
                        "english_name": tract.english_name,
                        "wards": [
                            {"id": w.id, "burmese_name": w.burmese_name, "english_name": w.english_name}
                            for w in tract.wards if w.is_active
                        ],
                    })
                townships.append({
                    "id": township.id,
                    "burmese_name": township.burmese_name,
                    "english_name": township.english_name,
                    "village_tracts": tracts,
                })
            districts.append({
                "id": district.id,
                "burmese_name": district.burmese_name,
                "english_name": district.english_name,
                "townships": townships,
            })
        result.append({
            "id": region.id,
            "burmese_name": region.burmese_name,
            "english_name": region.english_name,
            "districts": districts,
        })
    return result


@router.get("/meta/form/current")
def current_form(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    """Return the currently published census form with its sections and fields."""
    version = (
        db.query(m.FormVersion)
        .filter(m.FormVersion.publication_status == "published")
        .order_by(m.FormVersion.published_at.desc(), m.FormVersion.id.desc())
        .first()
    )
    if not version:
        version = db.query(m.FormVersion).order_by(m.FormVersion.id.desc()).first()
    if not version:
        raise HTTPException(status_code=404, detail="No census form has been defined")

    form = db.get(m.Form, version.form_id)
    fields = (
        db.query(m.FormField)
        .filter(m.FormField.form_version_id == version.id, m.FormField.is_enabled == True)  # noqa: E712
        .order_by(m.FormField.display_order, m.FormField.id)
        .all()
    )
    sections = (
        db.query(m.FormSection)
        .filter(m.FormSection.form_version_id == version.id)
        .order_by(m.FormSection.display_order, m.FormSection.id)
        .all()
    )
    return {
        "form_id": form.form_id if form else None,
        "burmese_title": form.burmese_title if form else None,
        "english_title": form.english_title if form else None,
        "version_number": version.version_number,
        "form_version_id": version.id,
        "publication_status": version.publication_status,
        "sections": [
            {
                "id": s.id,
                "title_burmese": s.title_burmese,
                "title_english": s.title_english,
                "description_burmese": s.description_burmese,
                "description_english": s.description_english,
                "display_order": s.display_order,
            }
            for s in sections
        ],
        "fields": [
            {
                "id": f.id,
                "name": f.name,
                "title_burmese": f.title_burmese,
                "title_english": f.title_english,
                "field_type": f.field_type,
                "is_required": f.is_required,
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
            for f in fields
        ],
    }


@router.get("/notifications")
def list_notifications(
    unread_only: bool = False,
    limit: int = 20,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    role = (user.role or "").lower()
    query = db.query(m.Notification).order_by(m.Notification.created_at.desc())
    # Admins see everything; reviewers also see admin-addressed rows; everyone
    # else only sees rows addressed to everyone (NULL) or to their own role.
    if role not in {"admin", "superuser"}:
        visible = ["admin", "reviewer"] if role == "reviewer" else [role]
        query = query.filter(
            or_(m.Notification.recipient_role.is_(None),
                m.Notification.recipient_role.in_(visible))
        )
    if unread_only:
        query = query.filter(m.Notification.is_read == False)  # noqa: E712
    rows = query.limit(max(1, min(limit, 100))).all()
    unread_q = db.query(func.count(m.Notification.id)).filter(m.Notification.is_read == False)  # noqa: E712
    if role not in {"admin", "superuser"}:
        visible = ["admin", "reviewer"] if role == "reviewer" else [role]
        unread_q = unread_q.filter(
            or_(m.Notification.recipient_role.is_(None),
                m.Notification.recipient_role.in_(visible))
        )
    unread = unread_q.scalar()
    return {
        "unread": int(unread or 0),
        "items": [
            {
                "id": n.id,
                "title_burmese": n.title_burmese,
                "title_english": n.title_english,
                "message_burmese": n.message_burmese,
                "message_english": n.message_english,
                "type": n.type,
                "is_read": n.is_read,
                "created_at": n.created_at.isoformat() if n.created_at else None,
            }
            for n in rows
        ],
    }


@router.post("/notifications/read-all")
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Mark every notification visible to the caller as read."""
    role = (user.role or "").lower()
    query = db.query(m.Notification).filter(m.Notification.is_read == False)  # noqa: E712
    if role not in {"admin", "superuser"}:
        visible = ["admin", "reviewer"] if role == "reviewer" else [role]
        query = query.filter(
            or_(m.Notification.recipient_role.is_(None),
                m.Notification.recipient_role.in_(visible))
        )
    updated = query.update({m.Notification.is_read: True}, synchronize_session=False)
    db.commit()
    return {"detail": "All notifications marked as read", "updated": int(updated or 0)}


@router.post("/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    n = db.get(m.Notification, notification_id)
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"detail": "Marked as read"}
