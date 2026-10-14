# backend/server/app/api/deps.py
"""Shared FastAPI dependencies: database session and authentication/authorization."""
from __future__ import annotations

from typing import Generator, Iterable

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.session import verify_session_token
from app.db.base import SessionLocal
from app.db.models import User


def get_db() -> Generator[Session, None, None]:
    """Dependency that provides a request-scoped database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user_optional(request: Request, db: Session = Depends(get_db)) -> User | None:
    """Return the authenticated user or ``None`` without raising."""
    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    payload = verify_session_token(token)
    if not payload:
        return None

    user = db.get(User, int(payload["uid"]))
    if not user or not user.is_active:
        return None
    # Revoked session (e.g. password changed / "log out everywhere").
    if int(payload.get("sv", 0)) != int(user.session_version or 0):
        return None
    return user


def get_current_user(
    user: User | None = Depends(get_current_user_optional),
) -> User:
    """Require an authenticated, active user."""
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    return user


def require_roles(*roles: str):
    """Return a dependency that requires the current user to hold one of *roles*.

    Administrators (``is_superuser``) always pass.
    """
    allowed: Iterable[str] = {r.lower() for r in roles}

    def _checker(user: User = Depends(get_current_user)) -> User:
        if user.is_superuser or (user.role or "").lower() in allowed:
            return user
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action",
        )

    return _checker


require_admin = require_roles("admin")


def is_admin(user: User) -> bool:
    return bool(user.is_superuser or (user.role or "").lower() == "admin")


def can_review(user: User) -> bool:
    return is_admin(user) or (user.role or "").lower() in {"reviewer"}
