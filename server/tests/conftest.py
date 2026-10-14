"""Pytest fixtures for the MOALI / LBVD census backend.

The environment is pinned to an isolated, throwaway SQLite database **before**
the ``app`` package is imported, because ``app.core.config`` and
``app.db.base`` capture ``DATABASE_URL`` at import time. A fresh database file
is created per run and removed when the session ends.
"""
from __future__ import annotations

import os
import tempfile
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Environment (MUST run before any ``app.*`` import)
# ---------------------------------------------------------------------------
_db_path = Path(tempfile.gettempdir()) / f"moali_test_{int(time.time() * 1000)}.db"
if _db_path.exists():
    _db_path.unlink()

os.environ["DATABASE_URL"] = f"sqlite:///{_db_path}"
os.environ["ENVIRONMENT"] = "test"
os.environ["SECRET_KEY"] = "test-secret-key-not-for-production"
os.environ["COOKIE_SECURE"] = "false"
os.environ["ADMIN_EMAIL"] = "admin@example.com"
os.environ["ADMIN_PASSWORD"] = "Admin@12345"
os.environ["ADMIN_NAME"] = "Test Admin"
# High limits keep unrelated tests from tripping the shared in-memory limiter.
os.environ["RATE_LIMIT_PER_MINUTE"] = "100000"
os.environ["AUTH_RATE_LIMIT_PER_MINUTE"] = "100000"
os.environ["LOGIN_MAX_ATTEMPTS"] = "1000"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

ADMIN_EMAIL = "admin@example.com"
ADMIN_PASSWORD = "Admin@12345"
BASE = "/api/v1"


@pytest.fixture(autouse=True, scope="session")
def _cleanup_db():
    yield
    if _db_path.exists():
        try:
            _db_path.unlink()
        except OSError:
            pass


@pytest.fixture()
def client():
    """A fresh TestClient per test with an empty cookie jar.

    The FastAPI lifespan (create_all + idempotent seed) runs for each test;
    the SQLite tables persist across tests within the session, but every test
    starts unauthenticated.
    """
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def admin_cookies(client):
    """Logged-in admin session cookie jar."""
    res = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    assert res.status_code == 200, res.text
    return res.cookies


@pytest.fixture()
def admin_headers(admin_cookies):
    return {"cookie": f"moali_session={admin_cookies.get('moali_session')}"}


def _register_and_login(client: TestClient, email: str, password: str):
    res = client.post(
        f"{BASE}/auth/register",
        json={"email": email, "name": email.split("@")[0], "password": password},
    )
    # 201 created, or 409 already exists
    assert res.status_code in (201, 409), res.text
    login = client.post(
        f"{BASE}/auth/login/cookie",
        json={"email": email, "password": password},
    )
    assert login.status_code == 200, login.text
    return login.cookies


@pytest.fixture()
def enumerator_cookies(client):
    """Self-registered enumerator session cookie jar."""
    return _register_and_login(client, "field@example.com", "Field@123456")


@pytest.fixture()
def enumerator_headers(enumerator_cookies):
    return {"cookie": f"moali_session={enumerator_cookies.get('moali_session')}"}


def get_first_id(client, path: str, cookie_name: str) -> int | None:
    """Return the id of the first row from a master list endpoint."""
    res = client.get(f"{BASE}{path}", headers={"cookie": f"moali_session={cookie_name}"})
    assert res.status_code == 200, res.text
    rows = res.json()
    assert isinstance(rows, list) and rows, f"expected rows from {path}"
    return rows[0]["id"]


@pytest.fixture()
def geo_ids(client, admin_cookies):
    """IDs of the first state-region, district and township from the seed."""
    return {
        "state_region_id": get_first_id(client, "/master/state-regions", admin_cookies["moali_session"]),
        "district_id": get_first_id(client, "/master/districts", admin_cookies["moali_session"]),
        "township_id": get_first_id(client, "/master/townships", admin_cookies["moali_session"]),
    }


@pytest.fixture()
def animal_type_id(client, admin_cookies) -> int:
    return get_first_id(client, "/master/animal-types", admin_cookies["moali_session"])


def make_submission_payload(**overrides) -> dict:
    """A minimal, valid submission body."""
    payload = {
        "household_no": f"HS-{int(time.time() * 1000)}",
        "interview_date": "2026-10-01",
        "respondent_name_burmese": "တောင်သူဦးတင်ဦး",
        "interviewer_name": "Daw Hla",
        "has_raised_animals": True,
        "has_poultry": False,
    }
    payload.update(overrides)
    return payload


@pytest.fixture()
def create_submission(client, admin_headers):
    """Factory that POSTs a submission with admin auth and returns response."""
    def _create(**overrides):
        return client.post(
            f"{BASE}/submissions",
            json=make_submission_payload(**overrides),
            headers=admin_headers,
        )

    return _create