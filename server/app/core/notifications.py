# backend/server/app/core/notifications.py
"""Helpers for writing durable, bilingual in-app notifications.

A notification is persisted in MySQL (never only pushed over the socket) so it
survives a page reload and shows up in the header bell and the Messages page.
The REST layer invalidates the ``notifications`` query after any realtime event,
so a row added inside the same transaction as a submission appears live.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.db import models as m


def create_notification(
    db: Session,
    *,
    title_burmese: str,
    message_burmese: str,
    title_english: str | None = None,
    message_english: str | None = None,
    type: str = "info",
    related_entity_type: str | None = None,
    related_entity_id: int | None = None,
    recipient_role: str | None = None,
    created_by: str | None = None,
) -> m.Notification:
    """Add a notification row to ``db`` (committed by the caller's transaction).

    ``recipient_role`` scopes visibility: admins always see everything; other
    roles only see rows addressed to ``None`` (everyone) or to their own role.
    """
    note = m.Notification(
        title_burmese=title_burmese,
        title_english=title_english,
        message_burmese=message_burmese,
        message_english=message_english,
        type=type,
        related_entity_type=related_entity_type,
        related_entity_id=related_entity_id,
        recipient_role=recipient_role,
        created_by=created_by,
        is_read=False,
    )
    db.add(note)
    return note
