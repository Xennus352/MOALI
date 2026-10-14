# backend/server/app/api/v1/ws.py
"""Authenticated real-time events over a single WebSocket endpoint.

Connection
----------
* Browser (React admin): opens ``/api/v1/ws``; the signed ``moali_session``
  cookie is attached to the WebSocket handshake automatically.
* Native (Flutter): opens ``/api/v1/ws?token=<session-token>`` because mobile
  WebSocket implementations cannot attach a Cookie header.

Delivery
--------
* REST endpoints publish events only *after* ``db.commit()`` succeeds, so a
  broadcast implies the event is durable in MySQL.
* Events are pushed onto an in-process queue from any thread and drained by a
  single asyncio consumer that fans them out to the sockets allowed to see them.
* This in-process fan-out is correct for the documented single-worker
  deployment. Running multiple uvicorn workers would require shared pub/sub
  (e.g. Redis); that is deliberately not introduced here.
"""
from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.config import settings
from app.core.session import verify_session_token
from app.db.base import SessionLocal
from app.db.models import User

logger = logging.getLogger("moali.ws")
router = APIRouter(tags=["realtime"])

# Custom close code used when the session is missing, invalid or revoked.
UNAUTHORIZED = 4401

_connections: dict[int, set[WebSocket]] = {}
_roles: dict[int, str] = {}
_loop: asyncio.AbstractEventLoop | None = None


def _load_session_user(token: str | None) -> User | None:
    """Resolve a signed session token to an active user (same rules as REST)."""
    payload = verify_session_token(token)
    if not payload:
        return None
    db = SessionLocal()
    try:
        user = db.get(User, int(payload["uid"]))
        if not user or not user.is_active:
            return None
        if int(payload.get("sv", 0)) != int(user.session_version or 0):
            return None
        return user
    finally:
        db.close()


async def _fanout(event_type: str, payload: dict[str, Any]) -> None:
    """Deliver one event to every socket allowed to receive it.

    A socket receives an event when it is either an explicit recipient
    (``_user_ids``) or belongs to one of the allowed roles (``_roles``) — an
    OR relationship, so the owner of a submission also hears about its review
    even when they are not an admin/reviewer.
    """
    roles = payload.pop("_roles", None)
    user_ids = payload.pop("_user_ids", None)
    stale: list[tuple[int, WebSocket]] = []
    for uid, sockets in list(_connections.items()):
        if user_ids is not None and uid in user_ids:
            pass  # explicitly targeted recipient
        elif roles is not None and (_roles.get(uid) or "") in roles:
            pass  # role-based recipient
        else:
            continue
        message = json.dumps({"type": event_type, "data": payload}, ensure_ascii=False)
        for ws in list(sockets):
            try:
                await ws.send_text(message)
            except Exception:
                stale.append((uid, ws))
    for uid, ws in stale:
        sockets = _connections.get(uid)
        if sockets:
            sockets.discard(ws)


def init_realtime() -> None:
    """Bind the event loop used to deliver events and reset stale sessions.

    Called from the application lifespan. Events are delivered on this loop via
    ``run_coroutine_threadsafe``, so a REST endpoint running in a worker thread
    can publish without blocking.
    """
    global _loop
    _loop = asyncio.get_running_loop()
    # A fresh application start must not inherit sockets loop-bound to a prior
    # event loop (relevant when several apps share the process, e.g. in tests).
    _connections.clear()
    _roles.clear()


def publish_event(
    event_type: str,
    payload: dict[str, Any],
    *,
    roles: list[str] | None = None,
    user_ids: list[int] | None = None,
) -> None:
    """Deliver a real-time event. Intended to be called *after* ``db.commit()``.

    Thread-safe: schedules the fan-out on the application loop. ``roles``
    restricts the audience by role; ``user_ids`` restricts it to specific users.
    Dropped silently when no realtime loop is bound (e.g. during unit tests that
    never started the app lifespan).
    """
    if roles:
        payload["_roles"] = [r.lower() for r in roles]
    if user_ids:
        payload["_user_ids"] = list(user_ids)
    loop = _loop
    if loop is None or loop.is_closed():
        return
    try:
        asyncio.run_coroutine_threadsafe(_fanout(event_type, payload), loop)
    except RuntimeError:
        # Loop shut down between the check and the call; nothing to deliver.
        pass


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    """Accept an authenticated real-time connection."""
    token = websocket.cookies.get(settings.SESSION_COOKIE_NAME)
    if not token:
        token = websocket.query_params.get("token")
    user = _load_session_user(token)
    if user is None:
        await websocket.close(code=UNAUTHORIZED)
        return

    await websocket.accept()
    _connections.setdefault(user.id, set()).add(websocket)
    _roles[user.id] = (user.role or "").lower()
    try:
        await websocket.send_json(
            {"type": "connected", "data": {"user_id": user.id, "role": user.role}}
        )
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if message.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.debug("websocket client left abnormally", exc_info=True)
    finally:
        sockets = _connections.get(user.id)
        if sockets is not None:
            sockets.discard(websocket)
            if not sockets:
                _connections.pop(user.id, None)
                _roles.pop(user.id, None)