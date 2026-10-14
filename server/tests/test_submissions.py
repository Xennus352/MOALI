"""Census submission CRUD, duplicate detection and the review workflow."""
from __future__ import annotations

import csv
import io

from tests.conftest import BASE, make_submission_payload


def _household(client, create_submission, key: str, **extra):
    """Create a submission with a unique household number and return the JSON body."""
    res = create_submission(household_no=f"{key}-0001", **extra)
    assert res.status_code == 201, res.text
    return res.json()


def _list(client, admin_headers, **params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return client.get(f"{BASE}/submissions?page=1&page_size=25&{qs}", headers=admin_headers)


def test_create_submission_success(create_submission):
    res = create_submission()
    assert res.status_code == 201
    body = res.json()
    assert body["household_no"].startswith("HS-")
    assert body["collection_status"] == "submitted"


def test_create_submission_scopes_age_fields(create_submission):
    res = create_submission(
        respondent_age=45,
        household_head_age=61,
        respondent_gender_id=None,
    )
    body = res.json()
    assert body["respondent_age"] == 45
    assert body["household_head_age"] == 61


def test_create_submission_validates_geography(create_submission):
    # bogus township id must be rejected
    bad = create_submission(
        township_id=999999,
        household_no="GEO-1",
        state_region_id=None,
        district_id=None,
    )
    assert bad.status_code in (400, 422)


def test_duplicate_household_rejected(client, create_submission):
    body = _household(client, create_submission, key="DUP")
    dup = create_submission(
        household_no=body["household_no"],
        interview_date=body["interview_date"],
        township_id=body.get("township_id"),
    )
    assert dup.status_code == 409
    assert "already exists" in dup.json()["detail"]


def test_allow_duplicate_bypasses_detection(client, create_submission):
    body = _household(client, create_submission, key="RERUN")
    res = create_submission(
        household_no=body["household_no"],
        interview_date=body["interview_date"],
        township_id=body.get("township_id"),
        allow_duplicate=True,
    )
    assert res.status_code == 201


def test_rejected_submission_can_be_resurveyed(client, create_submission, admin_headers):
    body = _household(client, create_submission, key="RESURVEY")
    sid = body["id"]
    reject = client.post(
        f"{BASE}/submissions/{sid}/review",
        json={"action": "reject", "notes": "bad interview"},
        headers=admin_headers,
    )
    assert reject.status_code == 200
    # Now the same household/date is allowed again (rejected rows are skipped).
    retry = create_submission(
        household_no=body["household_no"],
        interview_date=body["interview_date"],
        township_id=body.get("township_id"),
    )
    assert retry.status_code == 201


def test_list_is_paginated(client, create_submission, admin_headers):
    _household(client, create_submission, key="PAGE")
    res = _list(client, admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert "items" in body and "total" in body and "page" in body
    assert body["page"] == 1


def test_list_filters_by_status(client, create_submission, admin_headers):
    _household(client, create_submission, key="FILTERED")
    res = _list(client, admin_headers, status="submitted")
    assert res.status_code == 200
    assert res.json()["total"] >= 1


def test_list_filters_by_search(client, create_submission, admin_headers):
    _household(client, create_submission, key="SEARCHABLE")
    res = _list(client, admin_headers, q="SEARCHABLE")
    assert res.status_code == 200
    assert res.json()["total"] >= 1


def test_review_approve_updates_status(client, create_submission, admin_headers):
    body = _household(client, create_submission, key="REVIEW")
    sid = body["id"]
    res = client.post(
        f"{BASE}/submissions/{sid}/review",
        json={"action": "approve", "notes": "All fields verified"},
        headers=admin_headers,
    )
    assert res.status_code == 200
    assert res.json()["collection_status"] == "approved"

    detail = client.get(f"{BASE}/submissions/{sid}", headers=admin_headers)
    assert detail.status_code == 200
    assert detail.json()["collection_status"] == "approved"
    assert len(detail.json()["review_history"]) >= 1


def test_review_full_workflow(client, create_submission, admin_headers):
    body = _household(client, create_submission, key="FLOW")
    sid = body["id"]
    for action, target in [
        ("start_review", "under_review"),
        ("approve", "approved"),
    ]:
        res = client.post(
            f"{BASE}/submissions/{sid}/review",
            json={"action": action, "notes": f"step {action}"},
            headers=admin_headers,
        )
        assert res.status_code == 200, res.text
        assert res.json()["collection_status"] == target
    # Only "reopen" is allowed from approved.
    blocked = client.post(
        f"{BASE}/submissions/{sid}/review",
        json={"action": "reject", "notes": "not allowed from approved"},
        headers=admin_headers,
    )
    assert blocked.status_code == 409
    reopened = client.post(
        f"{BASE}/submissions/{sid}/review",
        json={"action": "reopen", "notes": "back to pool"},
        headers=admin_headers,
    )
    assert reopened.status_code == 200
    assert reopened.json()["collection_status"] == "reopened"


def test_review_requires_valid_action(client, create_submission, admin_headers):
    body = _household(client, create_submission, key="BADACT")
    res = client.post(
        f"{BASE}/submissions/{body['id']}/review",
        json={"action": "delete_everything", "notes": "nope"},
        headers=admin_headers,
    )
    assert res.status_code == 422


def test_enumerator_can_create_own_submissions(client, enumerator_headers):
    res = client.post(
        f"{BASE}/submissions",
        json=make_submission_payload(household_no="ENUM-1"),
        headers=enumerator_headers,
    )
    assert res.status_code == 201


def test_export_csv_returns_csv_with_household_rows(client, create_submission, admin_headers):
    _household(client, create_submission, key="CSV")
    res = client.get(f"{BASE}/submissions/export.csv", headers=admin_headers)
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("text/csv")
    text = res.content.decode("utf-8-sig", errors="replace")
    rows = list(csv.DictReader(io.StringIO(text)))
    assert rows, "export should contain at least one row"
    assert "household_no" in rows[0]
    assert any("HS-" in (row.get("household_no") or "") for row in rows)


def test_export_csv_includes_age_columns(client, create_submission, admin_headers):
    _household(client, create_submission, key="CSVAGE", respondent_age=37, household_head_age=58)
    res = client.get(f"{BASE}/submissions/export.csv", headers=admin_headers)
    text = res.content.decode("utf-8-sig", errors="replace")
    rows = list(csv.DictReader(io.StringIO(text)))
    header = set(rows[0].keys())
    assert "respondent_age" in header and "household_head_age" in header

def _publish_custom_form(client, admin_headers, form_id: str, fields: list[dict]) -> int:
    """Create + publish a draft form and return its form_version_id."""
    created = client.post(
        f"{BASE}/forms",
        json={"form_id": form_id, "burmese_title": f"{form_id} test form",
              "english_title": "Test Form", "description": "created by tests"},
        headers=admin_headers,
    )
    assert created.status_code == 201, created.text

    sections = client.put(
        f"{BASE}/forms/{form_id}/sections",
        json=[{"title_burmese": "ထပ်ဆောင်း", "title_english": "Extra", "display_order": 1}],
        headers=admin_headers,
    )
    assert sections.status_code == 200, sections.text
    section_id = sections.json()["form_sections"][0]["id"]

    payload = [{**f, "associated_section_id": section_id} for f in fields]
    fields_res = client.put(
        f"{BASE}/forms/{form_id}/fields",
        json=payload,
        headers=admin_headers,
    )
    assert fields_res.status_code == 200, fields_res.text

    published = client.post(f"{BASE}/forms/{form_id}/publish", headers=admin_headers)
    assert published.status_code == 200, published.text

    detail = client.get(f"{BASE}/forms/{form_id}", headers=admin_headers)
    assert detail.status_code == 200
    return detail.json()["form_version_id"]


def test_additional_admin_fields_persist_as_answers(client, create_submission, admin_headers):
    """Admin-authored inputs that are not part of the fixed schema are stored
    as FormFieldAnswer rows and returned on the detail payload."""
    version_id = _publish_custom_form(
        client, admin_headers, "extra-fields",
        [
            {"name": "household_storage", "title_burmese": "ဆန်သိုလှောင်မှု",
             "field_type": "short_text", "is_required": False,
             "display_order": 1, "option_source": "static"},
            {"name": "cattle_total", "title_burmese": "စုစုပေါင်းနွား",
             "field_type": "integer", "is_required": False,
             "display_order": 2, "option_source": "static"},
        ],
    )

    res = create_submission(
        household_no="EXTRA-1",
        form_version_id=version_id,
        additional_data={
            "household_storage": "50 အိတ်",
            "cattle_total": 12,
            "unknown_key_ignored": "not stored",
        },
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["additional_data"] == {
        "household_storage": "50 အိတ်",
        "cattle_total": 12,
    }, "unmatched keys should be dropped and values typed correctly"

    sid = body["id"]
    detail = client.get(f"{BASE}/submissions/{sid}", headers=admin_headers)
    assert detail.status_code == 200
    assert detail.json()["additional_data"]["cattle_total"] == 12


def test_update_replaces_additional_answers(client, create_submission, admin_headers):
    version_id = _publish_custom_form(
        client, admin_headers, "extra-update",
        [
            {"name": "household_storage", "title_burmese": "ဆန်သိုလှောင်မှု",
             "field_type": "short_text", "is_required": False, "display_order": 1},
        ],
    )
    res = create_submission(
        household_no="EXTRAU-1",
        form_version_id=version_id,
        additional_data={"household_storage": "50"},
    )
    assert res.status_code == 201, res.text
    sid = res.json()["id"]

    patched = client.patch(
        f"{BASE}/submissions/{sid}",
        json={"additional_data": {"household_storage": "80", "cattle_total": 3}},
        headers=admin_headers,
    )
    assert patched.status_code == 200, patched.text
    assert patched.json()["additional_data"]["household_storage"] == "80"

    # Existing answers are replaced, not merged.
    cleared = client.patch(
        f"{BASE}/submissions/{sid}",
        json={"additional_data": {}},
        headers=admin_headers,
    )
    assert cleared.status_code == 200
    assert cleared.json()["additional_data"] == {}
