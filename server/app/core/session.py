# backend/server/app/core/session.py
"""Signed, stateless session tokens stored in an httpOnly cookie.

The token is a compact, URL-safe, HMAC-SHA256 signed payload:

    base64url(json({uid, role, sv, exp})).base64url(hmac)

Design goals:
  * The browser can never tamper with the payload (signature verified with the
    server secret), which fixes the previous forgeable ``id:role:email`` cookie.
  * Sessions expire (``exp``).
  * Sessions can be revoked server-side by bumping ``users.session_version``
    (``sv``); changing a password or "log out everywhere" invalidates every
    previously issued cookie for that user.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from typing import Any

from app.core.config import settings


def _b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _b64decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _sign(message: bytes) -> str:
    digest = hmac.new(settings.SECRET_KEY.encode("utf-8"), message, hashlib.sha256).digest()
    return _b64encode(digest)


def create_session_token(
    user_id: int,
    role: str,
    session_version: int = 0,
    max_age_seconds: int | None = None,
    purpose: str | None = None,
) -> str:
    """Return a signed session token for the given user.

    ``purpose`` tags a token for a narrow use (e.g. ``"handoff"`` for the short
    lived token handed back to a native app during OAuth). Tokens carrying a
    purpose are only accepted by :func:`verify_session_token` when the caller
    asks for that same purpose, so a handoff token can never be replayed as a
    normal session cookie.
    """
    max_age = max_age_seconds if max_age_seconds is not None else settings.SESSION_MAX_AGE_SECONDS
    payload: dict[str, Any] = {
        "uid": int(user_id),
        "role": role,
        "sv": int(session_version),
        "exp": int(time.time()) + int(max_age),
    }
    if purpose:
        payload["purpose"] = purpose
    encoded = _b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = _sign(encoded.encode("ascii"))
    return f"{encoded}.{signature}"


def verify_session_token(
    token: str | None, purpose: str | None = None
) -> dict[str, Any] | None:
    """Validate a session token and return its payload, or ``None`` if invalid.

    When ``purpose`` is given the token must carry exactly that purpose; when it
    is omitted any purpose (including none) is accepted, preserving the normal
    cookie behaviour.
    """
    if not token or "." not in token:
        return None
    try:
        encoded, signature = token.rsplit(".", 1)
    except ValueError:
        return None

    expected = _sign(encoded.encode("ascii"))
    if not hmac.compare_digest(expected, signature):
        return None

    try:
        payload = json.loads(_b64decode(encoded))
    except (ValueError, json.JSONDecodeError):
        return None

    if not isinstance(payload, dict):
        return None
    if int(payload.get("exp", 0)) < int(time.time()):
        return None
    if "uid" not in payload:
        return None
    if purpose is not None:
        if payload.get("purpose") != purpose:
            return None
    elif payload.get("purpose") is not None:
        # A purpose-scoped token (e.g. a short-lived OAuth handoff) must never be
        # accepted by generic verification such as the session-cookie dependency.
        return None
    return payload


def sign_payload(payload: dict[str, Any], max_age_seconds: int, purpose: str) -> str:
    """Sign an arbitrary short-lived payload (e.g. the OAuth CSRF context)."""
    body = dict(payload)
    body["purpose"] = purpose
    body["exp"] = int(time.time()) + int(max_age_seconds)
    encoded = _b64encode(json.dumps(body, separators=(",", ":")).encode("utf-8"))
    return f"{encoded}.{_sign(encoded.encode('ascii'))}"


def verify_payload(token: str | None, purpose: str) -> dict[str, Any] | None:
    """Verify a payload produced by :func:`sign_payload`, or ``None``."""
    if not token or "." not in token:
        return None
    try:
        encoded, signature = token.rsplit(".", 1)
    except ValueError:
        return None
    if not hmac.compare_digest(_sign(encoded.encode("ascii")), signature):
        return None
    try:
        payload = json.loads(_b64decode(encoded))
    except (ValueError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    if payload.get("purpose") != purpose:
        return None
    if int(payload.get("exp", 0)) < int(time.time()):
        return None
    return payload
