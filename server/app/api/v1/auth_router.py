# backend/server/app/api/v1/auth_router.py
"""Authentication: register, login, session, logout and (optional) Google OAuth."""
from __future__ import annotations

import secrets
import urllib.parse
import urllib.request
import json
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.audit import record_audit
from app.core.config import settings
from app.core.passwords import hash_password, verify_password
from app.core.security import rate_limit_auth, get_client_ip
from app.core.session import (
    create_session_token,
    sign_payload,
    verify_payload,
    verify_session_token,
)
from app.db.models import OAuthAccount, User
from app.schemas.user import (
    ChangePasswordSchema,
    CreateUserSchema,
    LoginUserSchema,
    UpdateUserSchema,
    UserSchema,
)

router = APIRouter(prefix="/auth", tags=["auth"])

_DUMMY_HASH = hash_password("this-value-is-never-a-real-password")


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def _set_session_cookie(response: Response, user: User) -> None:
    token = create_session_token(user.id, user.role or "user", user.session_version or 0)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
        domain=settings.COOKIE_DOMAIN,
        max_age=settings.SESSION_MAX_AGE_SECONDS,
        path="/",
    )


def _session_payload(user: User) -> dict:
    return {
        "id": str(user.id),
        "name": user.name or user.email.split("@")[0],
        "email": user.email,
        "role": user.role or "user",
        "is_superuser": bool(user.is_superuser),
    }


def _authenticate(db: Session, email: str, password: str) -> User:
    """Validate credentials with constant-time-ish behaviour and lockout."""
    user = db.query(User).filter(User.email == email.lower().strip()).first()

    # Always run a verification to reduce user-enumeration timing differences.
    if user is None:
        verify_password(password, _DUMMY_HASH)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")

    now = datetime.now(timezone.utc)
    if user.locked_until is not None and user.locked_until > now:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Account temporarily locked after too many failed attempts. Try again later.",
        )

    if not verify_password(password, user.password_hash):
        user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
        if user.failed_login_attempts >= settings.LOGIN_MAX_ATTEMPTS:
            user.locked_until = now + timedelta(seconds=settings.LOGIN_LOCKOUT_SECONDS)
            user.failed_login_attempts = 0
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This account is disabled")

    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    db.commit()
    db.refresh(user)
    return user


# --------------------------------------------------------------------------
# registration
# --------------------------------------------------------------------------
@router.post("/register", response_model=UserSchema, status_code=status.HTTP_201_CREATED)
def register(
    payload: CreateUserSchema,
    request: Request,
    db: Session = Depends(get_db),
    _: None = Depends(rate_limit_auth),
):
    """Self-service registration. New accounts receive a low-privilege role."""
    email = payload.email.lower().strip()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    if len(payload.password) < settings.PASSWORD_MIN_LENGTH:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters",
        )

    # Self-registration must never be able to create privileged accounts.
    role = "enumerator"
    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        name=payload.name,
        role=role,
        is_active=True,
        is_superuser=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    record_audit(
        db, action="user.register", entity_type="user", entity_id=user.id,
        actor_id=user.id, after={"email": email, "role": role}, request=request, commit=True,
    )
    return user


# --------------------------------------------------------------------------
# login
# --------------------------------------------------------------------------
@router.post("/login")
@router.post("/login/cookie")
def login(
    payload: LoginUserSchema,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    _: None = Depends(rate_limit_auth),
):
    user = _authenticate(db, payload.email, payload.password)
    _set_session_cookie(response, user)
    record_audit(
        db, action="user.login", entity_type="user", entity_id=user.id,
        actor_id=user.id, request=request, commit=True,
    )
    return {"detail": "Logged in", "redirect": "/dashboard", "user": _session_payload(user)}


@router.get("/me")
def get_current_session_user(user: User = Depends(get_current_user)):
    return _session_payload(user)


@router.patch("/me", response_model=UserSchema)
def update_profile(
    payload: UpdateUserSchema,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Users may update their own display name only (not role/permissions)."""
    if payload.name is not None:
        user.name = payload.name
    db.commit()
    db.refresh(user)
    record_audit(db, action="user.update_self", entity_type="user", entity_id=user.id,
                 actor_id=user.id, request=request, commit=True)
    return user


@router.post("/change-password")
def change_password(
    payload: ChangePasswordSchema,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is incorrect")
    if len(payload.new_password) < settings.PASSWORD_MIN_LENGTH:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters",
        )
    user.password_hash = hash_password(payload.new_password)
    user.session_version = (user.session_version or 0) + 1  # revoke other sessions
    db.commit()
    record_audit(db, action="user.change_password", entity_type="user", entity_id=user.id,
                 actor_id=user.id, request=request, commit=True)
    return {"detail": "Password updated. Please sign in again."}


@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    user: User | None = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user is not None:
        record_audit(db, action="user.logout", entity_type="user", entity_id=user.id,
                     actor_id=user.id, request=request, commit=True)
    response.delete_cookie(
        key=settings.SESSION_COOKIE_NAME,
        path="/",
        domain=settings.COOKIE_DOMAIN,
        httponly=True,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
    )
    return {"detail": "Logged out"}


# --------------------------------------------------------------------------
# Google OAuth (optional — requires GOOGLE_CLIENT_ID/SECRET to be configured)
# --------------------------------------------------------------------------
# Two completion paths share the same callback:
#   * Web: the browser ends up back on the frontend with the session cookie set.
#   * Native (Flutter): a custom-scheme deep link (``moali://auth``) receives a
#     short-lived *handoff* token which the app POSTs to
#     ``/auth/session/exchange`` to obtain a real session token. The handoff
#     token is signed with the same secret but tagged ``purpose="handoff"`` and
#     expires in two minutes, so it is useless if it leaks into a log or history.
OAUTH_HANDOFF_TTL_SECONDS = 120
_OAUTH_CTX_COOKIE = "moali_oauth_ctx"
_OAUTH_CTX_TTL_SECONDS = 600


class SessionExchangeIn(BaseModel):
    token: str


def _is_allowed_mobile_redirect(uri: str | None) -> bool:
    """Accept only the configured deep link or URIs on the mobile scheme.

    This is what keeps ``/auth/google`` from becoming an open redirect that
    could be pointed at an attacker-controlled URL.
    """
    if not uri:
        return False
    if uri == settings.MOBILE_REDIRECT_URI:
        return True
    scheme = (settings.MOBILE_URL_SCHEME or "").strip()
    return bool(scheme) and uri.startswith(f"{scheme}://")


def _set_oauth_context(response: Response, state: str, redirect_uri: str | None) -> None:
    """Remember the CSRF state and any native redirect in a signed cookie."""
    value = sign_payload(
        {"state": state, "redirect": redirect_uri},
        _OAUTH_CTX_TTL_SECONDS,
        "oauth_state",
    )
    response.set_cookie(
        _OAUTH_CTX_COOKIE,
        value,
        httponly=True,
        secure=settings.COOKIE_SECURE,
        samesite="lax",
        max_age=_OAUTH_CTX_TTL_SECONDS,
        path="/",
    )


def _clear_oauth_context(response: Response) -> None:
    response.delete_cookie(_OAUTH_CTX_COOKIE, path="/")
    # Retire the legacy state-only cookie as well, if present.
    response.delete_cookie("moali_oauth_state", path="/")


@router.get("/google")
def google_login(request: Request, redirect_uri: str | None = None):
    """Begin Google sign-in.

    Pass ``redirect_uri=moali://auth`` from the mobile app to receive a handoff
    token via deep link; omit it for the browser/frontend flow.
    """
    if not settings.google_oauth_configured:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=(
                "Google sign-in is not configured on this server. Set GOOGLE_CLIENT_ID "
                "and GOOGLE_CLIENT_SECRET, then register the redirect URI with Google."
            ),
        )

    native_redirect: str | None = None
    if redirect_uri:
        if not _is_allowed_mobile_redirect(redirect_uri):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported redirect_uri",
            )
        native_redirect = redirect_uri

    state = secrets.token_urlsafe(24)
    params = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": "openid email profile",
        "access_type": "offline",
        "state": state,
        "prompt": "select_account",
    }
    url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(params)
    response = RedirectResponse(url)
    _set_oauth_context(response, state, native_redirect)
    return response


@router.get("/google/callback")
def google_callback(
    request: Request,
    code: str | None = None,
    state: str | None = None,
    db: Session = Depends(get_db),
):
    """Handle the Google OAuth callback and establish a session."""
    if not settings.google_oauth_configured:
        raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED,
                            detail="Google sign-in is not configured")

    ctx = verify_payload(request.cookies.get(_OAUTH_CTX_COOKIE), "oauth_state")
    if ctx is None:
        # Backwards compatibility with the legacy state-only cookie flow.
        legacy_state = request.cookies.get("moali_oauth_state")
        if legacy_state and state and legacy_state == state:
            ctx = {"state": state, "redirect": None}
    expected_state = ctx.get("state") if ctx else None
    if not code or not state or not expected_state or state != expected_state:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OAuth state")

    token_data = urllib.parse.urlencode({
        "code": code,
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "grant_type": "authorization_code",
    }).encode()
    try:
        with urllib.request.urlopen("https://oauth2.googleapis.com/token", token_data, timeout=10) as resp:
            tokens = json.loads(resp.read().decode())
        with urllib.request.urlopen(
            "https://openidconnect.googleapis.com/v1/userinfo",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
            timeout=10,
        ) as resp:
            profile = json.loads(resp.read().decode())
    except Exception as exc:  # pragma: no cover - network dependent
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Google login failed: {exc}")

    email = (profile.get("email") or "").lower()
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")

    user = db.query(User).filter(User.email == email).first()
    if user is None:
        user = User(
            email=email,
            password_hash="!",  # OAuth-only account: unusable password
            name=profile.get("name"),
            role="enumerator",
            is_active=True,
        )
        db.add(user)

    db.flush()
    account = (
        db.query(OAuthAccount)
        .filter(OAuthAccount.provider == "google", OAuthAccount.provider_user_id == profile.get("sub"))
        .first()
    )
    if account is None:
        db.add(OAuthAccount(
            user_id=user.id,
            provider="google",
            provider_user_id=profile.get("sub"),
            provider_username=profile.get("name"),
            scope="openid email profile",
        ))
    db.commit()
    db.refresh(user)

    record_audit(
        db, action="user.login_google", entity_type="user", entity_id=user.id,
        actor_id=user.id, request=request, commit=True,
    )

    native_redirect = ctx.get("redirect")
    if native_redirect:
        # Native app: hand back a short-lived, single-purpose token via deep link.
        handoff = create_session_token(
            user.id,
            user.role or "user",
            user.session_version or 0,
            max_age_seconds=OAUTH_HANDOFF_TTL_SECONDS,
            purpose="handoff",
        )
        separator = "&" if "?" in native_redirect else "?"
        target = f"{native_redirect}{separator}token={urllib.parse.quote(handoff)}"
        redirect = RedirectResponse(url=target)
        _clear_oauth_context(redirect)
        return redirect

    redirect = RedirectResponse(url=f"{settings.FRONTEND_URL}/dashboard")
    _set_session_cookie(redirect, user)
    _clear_oauth_context(redirect)
    return redirect


@router.post("/session/exchange")
def exchange_handoff_session(
    payload: SessionExchangeIn,
    response: Response,
    db: Session = Depends(get_db),
):
    """Redeem a native OAuth handoff token for a full session token."""
    data = verify_session_token(payload.token, purpose="handoff")
    if not data:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired handoff token")

    user = db.get(User, int(data["uid"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account is not available")
    if int(data.get("sv", 0)) != int(user.session_version or 0):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session has been revoked")

    token = create_session_token(user.id, user.role or "user", user.session_version or 0)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
        domain=settings.COOKIE_DOMAIN,
        max_age=settings.SESSION_MAX_AGE_SECONDS,
        path="/",
    )
    return {"token": token, "user": _session_payload(user)}

