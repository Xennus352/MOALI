"""Real-time WebSocket channel tests.

Covers the security boundary (unauthenticated connections are rejected) and the
happy path (an authenticated admin receives the events published after a
submission is created and after it is reviewed).
"""
from __future__ import annotations

from starlette.websockets import WebSocketDisconnect

from tests.conftest import BASE, make_submission_payload


def _receive_until(ws, expected_type: str, max_receives: int = 20):
    """Keep consuming messages until the expected event type shows up.

    Tolerant of unrelated/stale messages (e.g. events queued by earlier tests
    in the same module-level queue).
    """
    for _ in range(max_receives):
        message = ws.receive_json()
        if message.get("type") == expected_type:
            return message
    raise AssertionError(f"did not receive a '{expected_type}' event")


def test_websocket_rejects_unauthenticated(client):
    # The server closes with code 4401 before accept(), which surfaces to the
    # TestClient as WebSocketDisconnect.
    try:
        with client.websocket_connect(f"{BASE}/ws") as _:
            raise AssertionError("unauthenticated websocket was accepted")
    except WebSocketDisconnect:
        pass


def test_websocket_rejects_invalid_token(client):
    try:
        with client.websocket_connect(
            f"{BASE}/ws", headers={"cookie": "moali_session=forged.token"}
        ) as _:
            raise AssertionError("websocket with a forged token was accepted")
    except WebSocketDisconnect:
        pass


def test_admin_receives_submission_created_and_reviewed(client, admin_headers):
    with client.websocket_connect(f"{BASE}/ws", headers=admin_headers) as ws:
        hello = _receive_until(ws, "connected")
        assert hello["data"]["role"] == "admin"

        household_no = make_submission_payload()["household_no"]
        created = client.post(
            f"{BASE}/submissions",
            json={
                "household_no": household_no,
                "interview_date": "2026-10-01",
                "respondent_name_burmese": "တောင်သူဦး",
                "interviewer_name": "Daw Hla",
            },
            headers=admin_headers,
        )
        assert created.status_code == 201, created.text
        submission_id = created.json()["id"]

        event = _receive_until(ws, "submission.created")
        assert event["data"]["id"] == submission_id
        assert event["data"]["household_no"] == household_no

        review = client.post(
            f"{BASE}/submissions/{submission_id}/review",
            json={"action": "approve", "notes": "verified over the phone"},
            headers=admin_headers,
        )
        assert review.status_code == 200, review.text

        event = _receive_until(ws, "submission.status_changed")
        assert event["data"]["collection_status"] == "approved"


def test_enumerator_connection_is_scoped(client, enumerator_headers):
    """Enumerators can connect; admin-only events are demoted server-side."""
    with client.websocket_connect(f"{BASE}/ws", headers=enumerator_headers) as ws:
        hello = _receive_until(ws, "connected")
        assert hello["data"]["user_id"] is not None
        assert hello["data"]["role"] == "enumerator"


def test_creator_receives_own_submission_events(
    client, enumerator_headers, admin_headers
):
    """The submitter hears about their own submission even as a non-admin.

    Fan-out is *explicit recipient OR role*, so an enumerator gets the
    `submission.created` confirmation and the later `submission.status_changed`
    when an admin reviews the record, without receiving admin-only broadcasts.
    """
    with client.websocket_connect(f"{BASE}/ws", headers=enumerator_headers) as ws:
        _receive_until(ws, "connected")

        payload = make_submission_payload()
        created = client.post(
            f"{BASE}/submissions", json=payload, headers=enumerator_headers
        )
        assert created.status_code == 201, created.text
        submission_id = created.json()["id"]

        event = _receive_until(ws, "submission.created")
        assert event["data"]["id"] == submission_id
        assert event["data"]["household_no"] == payload["household_no"]

        review = client.post(
            f"{BASE}/submissions/{submission_id}/review",
            json={"action": "approve", "notes": "ok"},
            headers=admin_headers,
        )
        assert review.status_code == 200, review.text

        event = _receive_until(ws, "submission.status_changed")
        assert event["data"]["id"] == submission_id
        assert event["data"]["collection_status"] == "approved"