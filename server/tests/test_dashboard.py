"""Dashboard aggregates should reflect real database rows, not hardcoded values.

Strategy: create N fresh submissions and assert the KPI counters move by the
same amount, then sanity-check the trend/recent payload shapes.
"""
from __future__ import annotations

from tests.conftest import BASE


def _create(client, headers, household_no: str):
    res = client.post(
        f"{BASE}/submissions",
        json={
            "household_no": household_no,
            "interview_date": "2026-10-01",
            "respondent_name_burmese": "တောင်သူ",
        },
        headers=headers,
    )
    assert res.status_code == 201, res.text
    return res.json()


def test_kpi_counts_move_with_inserts(client, admin_headers):
    before = client.get(f"{BASE}/dashboard/kpi", headers=admin_headers)
    assert before.status_code == 200
    before_total = before.json()["totalSubmissions"]

    _create(client, admin_headers, "KPI-A-1")
    _create(client, admin_headers, "KPI-A-2")

    after = client.get(f"{BASE}/dashboard/kpi", headers=admin_headers).json()
    assert after["totalSubmissions"] == before_total + 2
    assert after["submissionsThisMonth"] >= before.json()["submissionsThisMonth"] + 2
    assert after["totalAnimals"] >= 0
    assert "approvedSubmissions" in after and "pendingReview" in after


def test_kpi_rejects_unauthenticated(client):
    assert client.get(f"{BASE}/dashboard/kpi").status_code == 401


def test_trends_shape_and_data(client, admin_headers):
    _create(client, admin_headers, "TREND-1")
    res = client.get(f"{BASE}/dashboard/trends?days=30", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    series = body["submissionsOverTime"]
    assert isinstance(series, list) and len(series) > 0
    assert sum(item["count"] for item in series) >= 1
    for key in ("submissionsByRegion", "submissionsByTownship", "submissionsByStatus",
                "animalsByType", "animalsByGender", "breedingByCategory"):
        assert key in body, f"trends missing {key}"
        assert isinstance(body[key], list)


def test_recent_returns_submissions_and_activity(client, admin_headers):
    _create(client, admin_headers, "RECENT-1")
    res = client.get(f"{BASE}/dashboard/recent?limit=6", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["submissions"], "recent submissions should exist"
    first = body["submissions"][0]
    assert "household_no" in first and "collection_status" in first
    assert isinstance(body["activity"], list)


def test_recent_activity_feeds_from_audit_log(client, admin_headers):
    res = client.get(f"{BASE}/dashboard/recent?limit=6", headers=admin_headers)
    actions = {item.get("action") for item in res.json()["activity"]}
    assert "submission.create" in actions or "auth.login" in actions