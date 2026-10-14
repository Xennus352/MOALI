# backend/server/app/core/audit.py
"""Small helper for writing tamper-evident audit log entries."""
from __future__ import annotations

import json
from typing import Any

from fastapi import Request
from sqlalchemy.orm import Session

from app.db.models import AuditLog

# Never persist these keys into an audit record.
_REDACTED_KEYS = {"password", "password_hash", "access_token", "refresh_token", "token"}


def _redact(payload: dict[str, Any] | None) -> str | None:
    if payload is None:
        return None
    safe = {k: ("***" if k in _REDACTED_KEYS else v) for k, v in payload.items()}
    try:
        return json.dumps(safe, default=str, ensure_ascii=False)
    except (TypeError, ValueError):
        return None


def record_audit(
    db: Session,
    *,
    action: str,
    entity_type: str,
    actor_id: Any = None,
    entity_id: int | None = None,
    before: dict[str, Any] | None = None,
    after: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
    request: Request | None = None,
    commit: bool = False,
) -> AuditLog:
    """Create an audit log row. Caller controls the transaction."""
    ip_address = None
    user_agent = None
    if request is not None:
        ip_address = request.client.host if request.client else None
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            ip_address = forwarded.split(",")[0].strip()
        user_agent = (request.headers.get("user-agent") or "")[:500]

    entry = AuditLog(
        actor_id=str(actor_id) if actor_id is not None else None,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        entity_before=_redact(before),
        entity_after=_redact(after),
        metadata=_redact(metadata),
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(entry)
    if commit:
        db.commit()
    return entry
