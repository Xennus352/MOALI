# backend/server/tests/test_regressions.py
"""Regression tests for bugs that previously caused intermittent 500s.

Two distinct defects are locked down here:

1. The ``RequestValidationError`` handler used to crash with "Object of type
   bytes is not JSON serializable" whenever the request body was not valid
   JSON (e.g. the client forgot ``Content-Type: application/json``). A 422 must
   stay a 422, never become a 500.
2. ``SessionLocal`` used to be a thread-local ``scoped_session``. FastAPI can run
   a sync dependency's teardown on a different threadpool thread, which leaked
   the original session's MySQL connection and produced "Packet sequence number
   wrong" under concurrency. Each request must get its own Session object.
"""
from __future__ import annotations

BASE = "/api/v1"


def test_non_json_body_returns_422_not_500(client, admin_headers):
    """A body sent without ``application/json`` must yield a clean 422 payload."""
    res = client.post(
        f"{BASE}/submissions",
        content=b'{"household_no":"x"}',
        headers={**admin_headers, "Content-Type": "text/plain"},
    )
    assert res.status_code == 422, res.text
    body = res.json()
    assert "detail" in body
    # The handler must have serialised the (bytes-bearing) errors successfully.
    assert isinstance(body.get("errors"), list)


def test_missing_required_fields_returns_422(client, admin_headers):
    """Valid JSON but incomplete payload -> 422 with the offending field."""
    res = client.post(
        f"{BASE}/submissions",
        json={"household_no": "x"},
        headers=admin_headers,
    )
    assert res.status_code == 422, res.text
    body = res.json()
    assert "detail" in body
    assert "interview_date" in str(body.get("field", "")) or "interview_date" in str(body)


def test_session_factory_returns_new_session_per_call():
    """Guards against reintroducing a thread-local ``scoped_session``.

    A scoped_session would return the *same* object for repeated calls on one
    thread, which is what leaked connections across FastAPI's threadpool.
    """
    from app.db.base import SessionLocal

    first = SessionLocal()
    second = SessionLocal()
    try:
        assert first is not second
    finally:
        first.close()
        second.close()


def test_concurrent_sessions_do_not_interfere():
    """Many threads each check out their own session without error."""
    from concurrent.futures import ThreadPoolExecutor

    from sqlalchemy import text

    from app.db.base import SessionLocal

    def work(_i: int) -> int:
        db = SessionLocal()
        try:
            return int(db.execute(text("SELECT 1")).scalar())
        finally:
            db.close()

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(work, range(48)))

    assert results == [1] * 48
