# backend/server/app/api/v1/admin.py
"""Administrator maintenance endpoints (currently: full data backup)."""
from __future__ import annotations

import base64
import json
from datetime import date, datetime, time
from decimal import Decimal

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_admin
from app.db.base import Base
from app.db.models import User

router = APIRouter(prefix="/admin", tags=["admin"])

# Columns that must never leave the server in a backup file.
_REDACT_COLUMNS = {"password_hash"}

# Reporting order: parents before children so the file is easy to re-import.
_TABLE_ORDER = [
    "state_regions", "districts", "townships", "village_tracts", "wards",
    "genders", "age_groups", "age_types", "animal_types", "animal_categories",
    "breeds", "species", "breeding_categories", "options",
    "users", "forms", "form_versions", "form_sections", "form_fields",
    "field_options", "submissions", "animal_counts", "breeding_counts",
    "form_field_answers", "notifications", "audit_logs", "oauth_accounts",
]


def _json_safe(value):
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if isinstance(value, (bytes, bytearray)):
        return base64.b64encode(bytes(value)).decode("ascii")
    return str(value)


def backup_payload(db: Session) -> dict:
    """Serialise every table to JSON-safe primitives."""
    tables: dict[str, list[dict]] = {}
    existing = set(Base.metadata.tables.keys())
    for name in _TABLE_ORDER + sorted(existing - set(_TABLE_ORDER)):
        if name not in existing:
            continue
        table = Base.metadata.tables[name]
        columns = [c for c in table.columns if c.name not in _REDACT_COLUMNS]
        rows = db.execute(select(*columns)).all()
        tables[name] = [
            {col.name: _json_safe(val) for col, val in zip(columns, row)}
            for row in rows
        ]
    return {
        "meta": {
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "table_count": len(tables),
            "row_counts": {k: len(v) for k, v in tables.items()},
        },
        "tables": tables,
    }


@router.get("/backup")
def download_backup(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Download a JSON snapshot of every important table (password hashes removed)."""
    payload = backup_payload(db)
    payload["meta"]["generated_by"] = admin.email
    body = json.dumps(payload, ensure_ascii=False, indent=2)
    stamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    filename = f"moali-backup-{stamp}.json"
    return Response(
        content=body,
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
        },
    )
