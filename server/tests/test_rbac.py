"""Role-based access control: only admins may touch admin surfaces."""
from __future__ import annotations

from tests.conftest import BASE


def test_unauthenticated_requests_rejected(client):
    assert client.get(f"{BASE}/dashboard/kpi").status_code == 401
    assert client.get(f"{BASE}/users").status_code == 401
    assert client.get(f"{BASE}/master/genders").status_code == 401
    assert client.post(f"{BASE}/submissions", json={}).status_code == 401


def test_enumerator_cannot_list_users(client, enumerator_headers):
    assert client.get(f"{BASE}/users", headers=enumerator_headers).status_code == 403


def test_enumerator_cannot_create_users(client, enumerator_headers):
    res = client.post(
        f"{BASE}/users",
        json={"email": "should-not@example.com", "password": "Nope@12345", "role": "admin"},
        headers=enumerator_headers,
    )
    assert res.status_code == 403


def test_enumerator_cannot_write_master_data(client, enumerator_headers):
    res = client.post(
        f"{BASE}/master/genders",
        json={"code": "X", "burmese_name": "တ", "english_name": "X"},
        headers=enumerator_headers,
    )
    assert res.status_code == 403


def test_enumerator_can_read_public_reference_data(client, enumerator_headers):
    assert client.get(f"{BASE}/master/genders", headers=enumerator_headers).status_code == 200
    assert client.get(f"{BASE}/meta/geography", headers=enumerator_headers).status_code == 200


def test_admin_can_manage_users(client, admin_headers):
    res = client.post(
        f"{BASE}/users",
        json={"email": "managed@example.com", "password": "Managed@123", "name": "Managed", "role": "enumerator"},
        headers=admin_headers,
    )
    assert res.status_code == 201
    uid = res.json()["id"]
    listing = client.get(f"{BASE}/users", headers=admin_headers)
    assert listing.status_code == 200
    assert any(u["id"] == uid for u in listing.json()["items"])


def test_enumerator_cannot_access_audit_log(client, enumerator_headers):
    assert client.get(f"{BASE}/users/audit-logs", headers=enumerator_headers).status_code == 403


def test_admin_can_access_audit_log(client, admin_headers):
    # Both the canonical audit path and the `/users/audit-logs` alias used by
    # the admin Security screen must resolve (the alias is registered before the
    # `{user_id}` route so it cannot be shadowed).
    for path in (f"{BASE}/audit-logs", f"{BASE}/users/audit-logs"):
        res = client.get(f"{path}?page=1&page_size=10", headers=admin_headers)
        assert res.status_code == 200, res.text
        body = res.json()
        assert "items" in body and "total" in body
        assert isinstance(body["items"], list)


def test_security_headers_present(client):
    res = client.get("/health")
    assert res.headers["x-content-type-options"] == "nosniff"
    assert res.headers["x-frame-options"] == "DENY"
    assert "default-src 'self'" in res.headers["content-security-policy"]
    assert res.headers["referrer-policy"] == "strict-origin-when-cross-origin"