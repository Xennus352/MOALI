"""Per-user data isolation and the native Google OAuth handoff flow.

Covers the two backend changes that support the Flutter user app:
  * enumerators only ever see/export/open their own submissions;
  * the browser OAuth flow can hand a short-lived token back to a native app,
    which is then exchanged (once) for a real session token.
"""
from __future__ import annotations

import json
import urllib.parse

from app.core.config import settings
from app.core.session import create_session_token, verify_payload, verify_session_token
from tests.conftest import BASE, make_submission_payload


# ---------------------------------------------------------------------------
# Data isolation
# ---------------------------------------------------------------------------
def test_enumerator_list_only_returns_own_submissions(
    client, admin_headers, enumerator_headers
):
    admin_res = client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="ADMIN-ONLY-1"),
        headers=admin_headers,
    )
    assert admin_res.status_code == 201, admin_res.text
    mine_res = client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="ENUM-OWN-1"),
        headers=enumerator_headers,
    )
    assert mine_res.status_code == 201, mine_res.text

    # Enumerator sees only their own, and the global total is not disclosed.
    seen = client.get(f"{BASE}/submissions?page=1&page_size=200", headers=enumerator_headers)
    assert seen.status_code == 200, seen.text
    households = {row["household_no"] for row in seen.json()["items"]}
    assert "ENUM-OWN-1" in households
    assert "ADMIN-ONLY-1" not in households
    # Every visible row belongs to the enumerator (created_by_user_id isolation).
    creator_ids = {row["created_by_user_id"] for row in seen.json()["items"]}
    assert len(creator_ids) == 1

    # Admin still sees both.
    admin_seen = client.get(f"{BASE}/submissions?page=1&page_size=200", headers=admin_headers)
    admin_households = {row["household_no"] for row in admin_seen.json()["items"]}
    assert {"ADMIN-ONLY-1", "ENUM-OWN-1"}.issubset(admin_households)


def test_admin_mine_filter_narrows_to_own(client, admin_headers, enumerator_headers):
    client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="ENUM-X"),
        headers=enumerator_headers,
    )
    client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="ADMIN-X"),
        headers=admin_headers,
    )
    res = client.get(f"{BASE}/submissions?mine=true&page_size=50", headers=admin_headers)
    assert res.status_code == 200, res.text
    households = {row["household_no"] for row in res.json()["items"]}
    assert "ENUM-X" not in households


def test_enumerator_cannot_open_others_submission(client, admin_headers, enumerator_headers):
    created = client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="PRIVATE-1"),
        headers=admin_headers,
    )
    sid = created.json()["id"]
    # 404 (not 403) so the record's existence is not disclosed.
    assert client.get(f"{BASE}/submissions/{sid}", headers=enumerator_headers).status_code == 404
    assert client.get(f"{BASE}/submissions/{sid}", headers=admin_headers).status_code == 200


def test_enumerator_export_is_scoped(client, admin_headers, enumerator_headers):
    client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="EXPORT-ADMIN"),
        headers=admin_headers,
    )
    client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="EXPORT-ENUM"),
        headers=enumerator_headers,
    )
    res = client.get(f"{BASE}/submissions/export.csv", headers=enumerator_headers)
    assert res.status_code == 200
    text = res.content.decode("utf-8-sig", errors="replace")
    assert "EXPORT-ENUM" in text
    assert "EXPORT-ADMIN" not in text


# ---------------------------------------------------------------------------
# Google OAuth native handoff
# ---------------------------------------------------------------------------
def test_google_login_requires_configuration(client):
    res = client.get(f"{BASE}/auth/google", follow_redirects=False)
    assert res.status_code == 501


def test_google_login_rejects_open_redirect(client, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "cid")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "secret")
    res = client.get(
        f"{BASE}/auth/google?redirect_uri=https://evil.example.com/steal",
        follow_redirects=False,
    )
    assert res.status_code == 400


def test_google_login_sets_signed_context_for_mobile(client, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "cid")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "secret")
    res = client.get(
        f"{BASE}/auth/google?redirect_uri=moali://auth",
        follow_redirects=False,
    )
    assert res.status_code in (302, 307)
    assert res.headers["location"].startswith("https://accounts.google.com/o/oauth2/v2/auth")

    ctx_cookie = res.cookies.get("moali_oauth_ctx")
    assert ctx_cookie, "signed oauth context cookie should be set"
    ctx = verify_payload(ctx_cookie, "oauth_state")
    assert ctx is not None
    assert ctx["redirect"] == "moali://auth"
    # The state echoed to Google must match the signed context.
    state = urllib.parse.parse_qs(
        urllib.parse.urlparse(res.headers["location"]).query
    )["state"][0]
    assert ctx["state"] == state


def test_handoff_token_exchange_and_rejection(client, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "cid")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "secret")

    class _FakeResp:
        def __init__(self, payload):
            self._payload = payload

        def read(self):
            return json.dumps(self._payload).encode()

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

    def fake_urlopen(url, *args, **kwargs):
        if "oauth2.googleapis.com" in str(url):
            return _FakeResp({"access_token": "fake-token"})
        return _FakeResp({"sub": "google-sub-1", "email": "google-user@example.com", "name": "G User"})

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    begin = client.get(f"{BASE}/auth/google?redirect_uri=moali://auth", follow_redirects=False)
    state = urllib.parse.parse_qs(urllib.parse.urlparse(begin.headers["location"]).query)["state"][0]

    callback = client.get(
        f"{BASE}/auth/google/callback?code=abc&state={state}",
        follow_redirects=False,
    )
    assert callback.status_code in (302, 307), callback.text
    location = callback.headers["location"]
    assert location.startswith("moali://auth?token=")
    handoff = urllib.parse.parse_qs(urllib.parse.urlparse(location).query)["token"][0]

    # The handoff token is single-purpose and must not work as a session cookie.
    assert verify_session_token(handoff) is None
    assert verify_session_token(handoff, purpose="handoff") is not None

    exchanged = client.post(f"{BASE}/auth/session/exchange", json={"token": handoff})
    assert exchanged.status_code == 200, exchanged.text
    body = exchanged.json()
    assert body["token"]
    assert body["user"]["email"] == "google-user@example.com"
    # The freshly issued token is a real, long-lived session token.
    assert verify_session_token(body["token"]) is not None


def test_exchange_rejects_a_normal_session_token(client, admin_headers, client_cookies=None):
    # A normal (non-handoff) token carries no purpose and must be refused here.
    normal = create_session_token(1, "enumerator", 0)
    res = client.post(f"{BASE}/auth/session/exchange", json={"token": normal})
    assert res.status_code == 401
