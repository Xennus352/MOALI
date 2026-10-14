# backend/server/app/api/v1/dashboard.py
"""Dashboard analytics computed from real database aggregates."""
from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.db import models as m
from app.db.models import User

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _local_day_start_utc() -> datetime:
    """Start of *today* in the configured timezone, expressed as naive UTC.

    ``Submission.created_at`` is stored as naive UTC, so a local 'today' window
    must be converted back to UTC before it is compared. This keeps the "Today"
    card correct for operators ahead of/behind UTC (e.g. Asia/Yangon, +06:30).
    """
    try:
        tz = ZoneInfo(settings.APP_TIMEZONE)
    except Exception:  # unknown tz name -> fall back to UTC
        tz = timezone.utc
    now_local = datetime.now(tz)
    start_local = datetime.combine(now_local.date(), time.min, tzinfo=tz)
    return start_local.astimezone(timezone.utc).replace(tzinfo=None)


@router.get("/kpi")
def dashboard_kpi(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    today_start = _local_day_start_utc()
    tomorrow_start = today_start + timedelta(days=1)
    week_ago = today_start - timedelta(days=6)
    month_ago = today_start - timedelta(days=29)

    total_submissions = db.query(func.count(m.Submission.id)).scalar() or 0
    submissions_today = (
        db.query(func.count(m.Submission.id))
        .filter(
            m.Submission.created_at >= today_start,
            m.Submission.created_at < tomorrow_start,
        )
        .scalar() or 0
    )
    submissions_week = (
        db.query(func.count(m.Submission.id))
        .filter(m.Submission.created_at >= week_ago)
        .scalar() or 0
    )
    submissions_month = (
        db.query(func.count(m.Submission.id))
        .filter(m.Submission.created_at >= month_ago)
        .scalar() or 0
    )

    def _status_count(value: str) -> int:
        return (
            db.query(func.count(m.Submission.id))
            .filter(m.Submission.collection_status == value)
            .scalar() or 0
        )

    pending = _status_count("under_review") + _status_count("submitted") + _status_count("pending")
    approved = _status_count("approved")
    rejected = _status_count("rejected")

    total_users = db.query(func.count(m.User.id)).scalar() or 0
    active_users = db.query(func.count(m.User.id)).filter(m.User.is_active == True).scalar() or 0  # noqa: E712

    # Livestock totals (sum of non-total animal count rows).
    total_animals = (
        db.query(func.coalesce(func.sum(m.AnimalCount.count), 0))
        .filter(m.AnimalCount.is_total == False)  # noqa: E712
        .scalar() or 0
    )
    total_breeding = (
        db.query(func.coalesce(func.sum(m.BreedingCount.male_count + m.BreedingCount.female_count), 0)).scalar()
        or 0
    )

    configured_fields = db.query(func.count(m.FormField.id)).filter(m.FormField.is_enabled == True).scalar() or 0  # noqa: E712

    form_status_rows = (
        db.query(m.Form.publication_status, func.count(m.Form.id))
        .group_by(m.Form.publication_status)
        .all()
    )

    households = db.query(func.count(func.distinct(m.Submission.household_no))).scalar() or 0

    return {
        "totalSubmissions": total_submissions,
        "submissionsToday": submissions_today,
        "submissionsThisWeek": submissions_week,
        "submissionsThisMonth": submissions_month,
        "totalHouseholds": households,
        "totalUsers": total_users,
        "activeUsers": active_users,
        "pendingReview": pending,
        "approvedSubmissions": approved,
        "rejectedSubmissions": rejected,
        "totalAnimals": int(total_animals),
        "totalBreedingStock": int(total_breeding),
        "configuredFields": configured_fields,
        "formPublicationStatus": {row[0] or "unknown": row[1] for row in form_status_rows},
    }


@router.get("/trends")
def dashboard_trends(
    days: int = 30,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    days = max(7, min(days, 365))
    since = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)

    # Submissions per day (fill gaps with zero so the chart is continuous).
    rows = (
        db.query(func.date(m.Submission.created_at).label("day"), func.count(m.Submission.id))
        .filter(m.Submission.created_at >= since)
        .group_by(func.date(m.Submission.created_at))
        .all()
    )
    by_day = {str(day): count for day, count in rows}
    series = []
    try:
        _tz = ZoneInfo(settings.APP_TIMEZONE)
    except Exception:
        _tz = timezone.utc
    _today = datetime.now(_tz).date()
    for i in range(days, -1, -1):
        d = (_today - timedelta(days=i)).isoformat()
        series.append({"date": d, "count": by_day.get(d, 0)})

    by_region = (
        db.query(m.StateRegion.burmese_name, func.count(m.Submission.id))
        .join(m.Submission, m.Submission.state_region_id == m.StateRegion.id, isouter=True)
        .group_by(m.StateRegion.burmese_name)
        .order_by(func.count(m.Submission.id).desc())
        .limit(15)
        .all()
    )
    by_township = (
        db.query(m.Township.burmese_name, func.count(m.Submission.id))
        .join(m.Submission, m.Submission.township_id == m.Township.id)
        .group_by(m.Township.burmese_name)
        .order_by(func.count(m.Submission.id).desc())
        .limit(10)
        .all()
    )
    by_status = (
        db.query(m.Submission.collection_status, func.count(m.Submission.id))
        .group_by(m.Submission.collection_status)
        .all()
    )
    # Livestock population by animal type (sum counts).
    animals_by_type = (
        db.query(m.AnimalType.burmese_name, func.coalesce(func.sum(m.AnimalCount.count), 0))
        .join(m.AnimalCount, m.AnimalCount.animal_type_id == m.AnimalType.id)
        .filter(m.AnimalCount.is_total == False)  # noqa: E712
        .group_by(m.AnimalType.burmese_name)
        .order_by(func.sum(m.AnimalCount.count).desc())
        .all()
    )
    by_gender = (
        db.query(m.AnimalCount.gender, func.coalesce(func.sum(m.AnimalCount.count), 0))
        .group_by(m.AnimalCount.gender)
        .all()
    )
    breeding_by_category = (
        db.query(
            m.BreedingCategory.burmese_name,
            func.coalesce(func.sum(m.BreedingCount.male_count + m.BreedingCount.female_count), 0),
        )
        .join(m.BreedingCount, m.BreedingCount.breeding_category_id == m.BreedingCategory.id)
        .group_by(m.BreedingCategory.burmese_name)
        .order_by(func.sum(m.BreedingCount.male_count + m.BreedingCount.female_count).desc())
        .all()
    )

    return {
        "submissionsOverTime": series,
        "submissionsByRegion": [{"region": r or "Unknown", "count": c} for r, c in by_region],
        "submissionsByTownship": [{"township": t or "Unknown", "count": c} for t, c in by_township],
        "submissionsByStatus": [{"status": s or "unknown", "count": c} for s, c in by_status],
        "animalsByType": [{"animalType": a or "Unknown", "count": int(c)} for a, c in animals_by_type],
        "animalsByGender": [{"gender": g or "unknown", "count": int(c)} for g, c in by_gender],
        "breedingByCategory": [{"category": c or "Unknown", "count": int(n)} for c, n in breeding_by_category],
    }


@router.get("/recent")
def dashboard_recent(
    limit: int = 8,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    limit = max(1, min(limit, 50))
    recent_subs = (
        db.query(m.Submission)
        .order_by(m.Submission.created_at.desc())
        .limit(limit)
        .all()
    )
    recent_audit = (
        db.query(m.AuditLog)
        .order_by(m.AuditLog.created_at.desc())
        .limit(limit)
        .all()
    )
    return {
        "submissions": [
            {
                "id": s.id,
                "household_no": s.household_no,
                "respondent_name_burmese": s.respondent_name_burmese,
                "township": s.township.burmese_name if s.township else None,
                "state_region": s.state_region.burmese_name if s.state_region else None,
                "collection_status": s.collection_status,
                "interview_date": s.interview_date.isoformat() if s.interview_date else None,
                "created_at": s.created_at.isoformat() if s.created_at else None,
            }
            for s in recent_subs
        ],
        "activity": [
            {
                "id": a.id,
                "actor_id": a.actor_id,
                "action": a.action,
                "entity_type": a.entity_type,
                "entity_id": a.entity_id,
                "created_at": a.created_at.isoformat() if a.created_at else None,
            }
            for a in recent_audit
        ],
    }
