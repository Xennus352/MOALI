"""Master / reference data CRUD and the schema-metadata endpoint."""
from __future__ import annotations

from tests.conftest import BASE


def test_master_meta_describes_resources(admin_headers, client):
    res = client.get(f"{BASE}/master/meta", headers=admin_headers)
    assert res.status_code == 200
    resources = res.json()["resources"]
    names = {r["resource"] for r in resources}
    for expected in ("genders", "animal-types", "species", "breeds", "age-groups",
                     "breeding-categories", "state-regions", "townships"):
        assert expected in names, f"{expected} missing from master meta"
    genders = next(r for r in resources if r["resource"] == "genders")
    field_names = {f["name"] for f in genders["fields"]}
    assert {"code", "burmese_name", "english_name"}.issubset(field_names)


def test_admin_creates_gender_then_deactivates(admin_headers, client):
    create = client.post(
        f"{BASE}/master/genders",
        json={"code": "NB", "burmese_name": "န", "english_name": "Non-binary", "display_order": 99},
        headers=admin_headers,
    )
    assert create.status_code == 201, create.text
    gid = create.json()["id"]

    listing = client.get(f"{BASE}/master/genders", headers=admin_headers)
    assert any(g["id"] == gid for g in listing.json())

    # Deactivate (records are never hard-deleted).
    gone = client.delete(f"{BASE}/master/genders/{gid}", headers=admin_headers)
    assert gone.status_code == 200
    active = client.get(f"{BASE}/master/genders", headers=admin_headers)
    assert all(g["id"] != gid for g in active.json())
    all_rows = client.get(f"{BASE}/master/genders?include_inactive=true", headers=admin_headers)
    target = next(g for g in all_rows.json() if g["id"] == gid)
    assert target["is_active"] is False


def test_duplicate_gender_code_rejected(admin_headers, client):
    first = client.post(
        f"{BASE}/master/genders",
        json={"code": "MG", "burmese_name": "မ", "english_name": "Male-ish"},
        headers=admin_headers,
    )
    assert first.status_code == 201
    dup = client.post(
        f"{BASE}/master/genders",
        json={"code": "MG", "burmese_name": "ဒု", "english_name": "Dup"},
        headers=admin_headers,
    )
    assert dup.status_code == 409


def test_patch_updates_master_row(admin_headers, client):
    create = client.post(
        f"{BASE}/master/age-groups",
        json={"code": "AGX", "burmese_name": "အသက်အ", "english_name": "Adult X", "min_age": 18, "max_age": 49},
        headers=admin_headers,
    )
    assert create.status_code == 201, create.text
    gid = create.json()["id"]
    patched = client.patch(
        f"{BASE}/master/age-groups/{gid}",
        json={"max_age": 59, "is_active": True},
        headers=admin_headers,
    )
    assert patched.status_code == 200
    assert patched.json()["max_age"] == 59


def test_geography_hierarchy_endpoint(admin_headers, client):
    res = client.get(f"{BASE}/meta/geography", headers=admin_headers)
    assert res.status_code == 200
    regions = res.json()  # top-level list of state regions
    assert isinstance(regions, list) and regions
    first = regions[0]
    assert "id" in first and "burmese_name" in first
    assert "districts" in first


def test_geography_hierarchy_crud_creates_district_and_township(admin_headers, client):
    # The production-grade seed ships only state regions; lower levels are
    # managed through the CRUD API. Verify the full chain works.
    sr = client.get(f"{BASE}/master/state-regions", headers=admin_headers).json()
    assert sr, "expected at least one state region from the seed"
    sid = sr[0]["id"]

    district = client.post(
        f"{BASE}/master/districts",
        json={"code": "DST01", "state_region_id": sid, "burmese_name": "ခရိုင်တစ်", "english_name": "District One"},
        headers=admin_headers,
    )
    assert district.status_code == 201, district.text
    did = district.json()["id"]

    township = client.post(
        f"{BASE}/master/townships",
        json={"code": "TW01", "district_id": did, "burmese_name": "မြို့နယ်တစ်", "english_name": "Township One"},
        headers=admin_headers,
    )
    assert township.status_code == 201, township.text
    tid = township.json()["id"]

    townships = client.get(f"{BASE}/master/townships", headers=admin_headers).json()
    assert any(t["id"] == tid for t in townships), "created township should be listed"
    # Townships expose their parents so the UI can render location pickers.
    assert any(t.get("district_id") == did for t in townships)

    tree = client.get(f"{BASE}/meta/geography", headers=admin_headers).json()
    region_node = next((r for r in tree if r["id"] == sid), None)
    assert region_node and any(d["id"] == did for d in region_node["districts"])

def test_meta_form_current_exposes_renderable_fields(admin_headers, client):
    """The mobile app renders the survey from this payload: every field must
    carry the metadata needed to build a dynamic input (type, required,
    option source, data binding, validation bounds, placeholder)."""
    res = client.get(f"{BASE}/meta/form/current", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    fields = body["fields"]
    assert fields, "expected the seeded census form to ship fields"

    bindings = {f["name"]: f for f in fields}
    geo = bindings["state_region_id"]
    assert geo["field_type"] == "geographic"
    assert geo["data_binding"] == "state_region"
    assert geo["option_source"] == "master"
    assert geo["is_required"] is True
    assert "placeholder_burmese" in geo

    # Any field the app has to render carries the full rendering contract.
    for f in fields:
        for key in ("name", "title_burmese", "field_type", "is_required",
                    "display_order", "associated_section_id", "option_source",
                    "data_binding", "placeholder_burmese", "unit",
                    "min_value", "max_value", "default_value"):
            assert key in f, f"{f['name']} missing '{key}'"

    # The five sections are intact so the app can build its wizard steps.
    assert len(body["sections"]) == 5
    assert all("title_burmese" in s for s in body["sections"])
