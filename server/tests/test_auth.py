"""Authentication and session-security tests.

These exercise the real cookie login flow, Argon2id password verification,
HMAC-signed sessions, revocation on password change, and logout.
"""
from __future__ import annotations

import re

import pytest

from tests.conftest import ADMIN_EMAIL, ADMIN_PASSWORD, BASE


def _cookie_from_headers(res) -> str:
    return res.headers.get("set-cookie", "")


def test_health_endpoint_reports_ok(client):
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert body["database"] is True


def test_admin_bootstrap_account_can_login(client):
    res = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["user"]["role"] == "admin"


def test_wrong_password_rejected(client):
    res = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": "WrongPassword9!"},
    )
    assert res.status_code == 401
    assert "email" in res.text.lower() or "password" in res.text.lower()


def test_session_cookie_is_http_only_and_signed(client):
    res = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    assert res.status_code == 200
    set_cookie = _cookie_from_headers(res)
    assert "moali_session=" in set_cookie
    assert "HttpOnly" in set_cookie
    assert "SameSite=Lax" in set_cookie or "SameSite=lax" in set_cookie
    # The session payload must be HMAC-signed: value pattern <payload>.<signature>
    m = re.search(r"moali_session=([^;]+)", set_cookie)
    assert m, "moali_session cookie missing"
    assert len(m.group(1).split(".")) >= 2, "cookie should carry an HMAC signature"


def test_me_returns_current_user(client):
    login = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    res = client.get(f"{BASE}/auth/me", cookies=login.cookies)
    assert res.status_code == 200
    body = res.json()
    assert body["email"] == ADMIN_EMAIL
    assert body["role"] == "admin"


def test_me_rejects_missing_or_tampered_cookie(client):
    assert client.get(f"{BASE}/auth/me").status_code == 401
    tampered = client.get(f"{BASE}/auth/me", cookies={"moali_session": "a.b"})
    assert tampered.status_code == 401


def test_register_creates_enumerator(client):
    res = client.post(
        f"{BASE}/auth/register",
        json={"email": "new-register@example.com", "name": "New Field", "password": "Field@98765"},
    )
    assert res.status_code == 201
    assert res.json()["role"] == "enumerator"
    # Two registrations with the same email must be rejected.
    dup = client.post(
        f"{BASE}/auth/register",
        json={"email": "new-register@example.com", "name": "New Field", "password": "Field@98765"},
    )
    assert dup.status_code in (400, 409)


def test_register_rejects_weak_password(client):
    res = client.post(
        f"{BASE}/auth/register",
        json={"email": "weak@example.com", "name": "Weak", "password": "short"},
    )
    assert res.status_code == 422


def test_change_password_revokes_existing_sessions(client):
    email, password = "pwchange@example.com", "First@1234"
    register = client.post(f"{BASE}/auth/register", json={"email": email, "name": "Pw", "password": password})
    assert register.status_code == 201
    login = client.post(f"{BASE}/auth/login/cookie", json={"email": email, "password": password})
    assert login.status_code == 200

    # The pre-change cookie is valid now…
    assert client.get(f"{BASE}/auth/me", cookies=login.cookies).status_code == 200

    # …but changing the password must invalidate that session immediately.
    change = client.post(
        f"{BASE}/auth/change-password",
        json={"current_password": password, "new_password": "Second@5678"},
        cookies=login.cookies,
    )
    assert change.status_code == 200
    assert client.get(f"{BASE}/auth/me", cookies=login.cookies).status_code == 401

    # The new password works, the old one does not.
    ok = client.post(f"{BASE}/auth/login/cookie", json={"email": email, "password": "Second@5678"})
    assert ok.status_code == 200
    old = client.post(f"{BASE}/auth/login/cookie", json={"email": email, "password": password})
    assert old.status_code == 401


def test_change_password_wrong_current_rejected(client, admin_headers):
    res = client.post(
        f"{BASE}/auth/change-password",
        json={"current_password": "definitely-wrong", "new_password": "Whatever@123"},
        headers=admin_headers,
    )
    assert res.status_code in (400, 401, 403)


def test_logout_invalidates_session(client):
    login = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    out = client.post(f"{BASE}/auth/logout", cookies=login.cookies)
    assert out.status_code == 200
    # The server clears the cookie; a fresh request is unauthenticated.
    assert client.get(f"{BASE}/auth/me").status_code == 401


def test_registration_rejects_none_email_role_escalation(client):
    res = client.post(
        f"{BASE}/auth/register",
        json={"email": "escalator@example.com", "name": "X", "password": "Field@12345", "role": "admin"},
    )
    assert res.status_code == 201
    body = res.json()
    assert body["role"] != "admin"
    assert body["is_superuser"] is False


@pytest.mark.parametrize("path", ["", "/api/v1"])
def test_auth_routes_mounted_at_both_prefixes(client, path):
    res = client.post(
        f"{path}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    assert res.status_code == 200