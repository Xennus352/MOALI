# backend/server/app/api/v1/users.py
"""Administrator user management and audit log access."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_admin
from app.api.v1.ws import publish_event
from app.core.audit import record_audit
from app.core.config import settings
from app.core.passwords import hash_password
from app.db import models as m
from app.db.models import User
from app.schemas.user import (
    AdminCreateUserSchema,
    ResetPasswordSchema,
    UpdateUserSchema,
    UserSchema,
)

router = APIRouter(tags=["users"])

VALID_ROLES = {"admin", "reviewer", "enumerator", "analyst", "user"}


def _serialize(user: User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": user.role,
        "is_active": user.is_active,
        "is_superuser": user.is_superuser,
        "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
    }


@router.get("/users")
def list_users(
    q: str | None = None,
    role: str | None = None,
    is_active: bool | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=200),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    query = db.query(User)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(User.email.ilike(like), User.name.ilike(like)))
    if role:
        query = query.filter(User.role == role)
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    total = query.count()
    rows = query.order_by(User.id.desc()).offset((page - 1) * page_size).limit(page_size).all()
    return {
        "items": [_serialize(u) for u in rows],
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": max(1, (total + page_size - 1) // page_size),
    }


@router.post("/users", status_code=status.HTTP_201_CREATED)
def create_user(
    payload: AdminCreateUserSchema,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    email = payload.email.lower().strip()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=409, detail="Email already registered")
    if payload.role not in VALID_ROLES:
        raise HTTPException(status_code=422, detail=f"role must be one of {sorted(VALID_ROLES)}")
    if payload.is_superuser and payload.role != "admin":
        raise HTTPException(status_code=422, detail="A superuser must have the admin role")

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        name=payload.name,
        role=payload.role,
        is_active=payload.is_active,
        is_superuser=payload.is_superuser,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    record_audit(db, action="user.admin_create", entity_type="user", entity_id=user.id,
                 actor_id=admin.id, after={"email": email, "role": payload.role}, request=request, commit=True)
    publish_event("user.changed", {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "is_active": user.is_active,
    }, roles=["admin"])
    return _serialize(user)


@router.get("/audit-logs")
@router.get("/users/audit-logs")  # alias matching the admin Security screen
def list_audit_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    entity_type: str | None = None,
    action: str | None = None,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    query = db.query(m.AuditLog)
    if entity_type:
        query = query.filter(m.AuditLog.entity_type == entity_type)
    if action:
        query = query.filter(m.AuditLog.action.ilike(f"%{action}%"))
    total = query.count()
    rows = (
        query.order_by(m.AuditLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [
            {
                "id": r.id,
                "actor_id": r.actor_id,
                "action": r.action,
                "entity_type": r.entity_type,
                "entity_id": r.entity_id,
                "metadata": r.metadata,
                "ip_address": r.ip_address,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": max(1, (total + page_size - 1) // page_size),
    }


@router.get("/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db), _admin: User = Depends(require_admin)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _serialize(user)


@router.patch("/users/{user_id}")
def update_user(
    user_id: int,
    payload: UpdateUserSchema,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.role is not None:
        if payload.role not in VALID_ROLES:
            raise HTTPException(status_code=422, detail=f"role must be one of {sorted(VALID_ROLES)}")
        user.role = payload.role
    if payload.name is not None:
        user.name = payload.name
    if payload.is_active is not None:
        # Never allow locking yourself out, or deactivating the last admin.
        if user.id == admin.id and not payload.is_active:
            raise HTTPException(status_code=422, detail="You cannot deactivate your own account")
        user.is_active = payload.is_active
    if payload.is_superuser is not None:
        if user.id == admin.id and not payload.is_superuser:
            raise HTTPException(status_code=422, detail="You cannot remove your own superuser flag")
        user.is_superuser = payload.is_superuser

    if user.is_superuser and user.role != "admin":
        user.role = "admin"

    db.commit()
    db.refresh(user)
    record_audit(db, action="user.update", entity_type="user", entity_id=user.id,
                 actor_id=admin.id, after=_serialize(user), request=request, commit=True)
    publish_event("user.changed", {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "is_active": user.is_active,
    }, roles=["admin"])
    return _serialize(user)


@router.post("/users/{user_id}/reset-password")
def reset_password(
    user_id: int,
    payload: ResetPasswordSchema,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    new_password = payload.new_password
    if len(new_password) < settings.PASSWORD_MIN_LENGTH:
        raise HTTPException(status_code=422, detail=f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.password_hash = hash_password(new_password)
    user.session_version = (user.session_version or 0) + 1  # revoke existing sessions
    user.failed_login_attempts = 0
    user.locked_until = None
    db.commit()
    record_audit(db, action="user.reset_password", entity_type="user", entity_id=user.id,
                 actor_id=admin.id, request=request, commit=True)
    return {"detail": "Password reset. The user's existing sessions were revoked."}


@router.post("/users/{user_id}/revoke-sessions")
def revoke_sessions(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.session_version = (user.session_version or 0) + 1
    db.commit()
    record_audit(db, action="user.revoke_sessions", entity_type="user", entity_id=user.id,
                 actor_id=admin.id, request=request, commit=True)
    return {"detail": "All sessions for this user were revoked."}


@router.delete("/users/{user_id}")
def deactivate_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=422, detail="You cannot deactivate your own account")
    user.is_active = False
    user.session_version = (user.session_version or 0) + 1
    db.commit()
    record_audit(db, action="user.deactivate", entity_type="user", entity_id=user.id,
                 actor_id=admin.id, request=request, commit=True)
    return {"detail": "User deactivated"}
