# backend/server/app/api/v1/master_data.py
"""CRUD endpoints for reference / master data.

Every resource follows the same shape:

    GET    /master/<resource>            list (search, include_inactive)
    GET    /master/<resource>/{id}       read one
    POST   /master/<resource>            create           (admin)
    PATCH  /master/<resource>/{id}       update           (admin)
    DELETE /master/<resource>/{id}       deactivate        (admin)

Records that are referenced elsewhere are never hard-deleted; they are
deactivated so historical submissions keep their meaning.
"""
from typing import Any, Optional, Type, Union, get_origin

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, create_model
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_admin
from app.core.audit import record_audit
from app.db import models as m
from app.db.models import User
from app.schemas import (
    AgeGroupSchema,
    AgeTypeSchema,
    AnimalCategorySchema,
    AnimalTypeSchema,
    BreedSchema,
    BreedingCategorySchema,
    DistrictSchema,
    GenderSchema,
    OptionSchema,
    SpeciesSchema,
    StateRegionSchema,
    TownshipSchema,
    VillageTractSchema,
    WardSchema,
)

router = APIRouter(prefix="/master", tags=["master-data"])

# Fields that a client may never set directly.
_PROTECTED = {"id", "created_at", "updated_at"}

# Registry populated by ``_register`` so the admin UI can discover resources
# and render generic create/edit forms without hard-coding the schema.
_RESOURCES: dict[str, dict[str, Any]] = {}


def _field_meta(schema_cls: Type[BaseModel]) -> list[dict[str, Any]]:
    """Turn a pydantic model into simple, UI-friendly field descriptors."""
    js = schema_cls.model_json_schema()
    required = set(js.get("required", []))
    fields: list[dict[str, Any]] = []
    for name, prop in js.get("properties", {}).items():
        if name in _PROTECTED:
            continue
        raw_type = prop.get("type")
        if isinstance(raw_type, list):  # Optional[...] -> ["string", "null"]
            raw_type = next((t for t in raw_type if t != "null"), "string")
        enum = prop.get("enum")
        # ``anyOf`` is how pydantic renders Optional[Enum]
        if enum is None and "anyOf" in prop:
            for branch in prop["anyOf"]:
                if "enum" in branch:
                    enum = branch["enum"]
                    break
        field: dict[str, Any] = {
            "name": name,
            "label": prop.get("title", name.replace("_", " ").title()),
            "type": raw_type or "string",
            "required": name in required,
        }
        for key in ("maxLength", "minLength", "minimum", "maximum"):
            if key in prop:
                field[key] = prop[key]
        if enum:
            field["enum"] = enum
        if "description" in prop:
            field["description"] = prop["description"]
        fields.append(field)
    return fields


def _dump(schema: BaseModel) -> dict[str, Any]:
    return schema.model_dump(exclude=_PROTECTED, exclude_none=False)


def _serialize(obj: Any) -> dict[str, Any]:
    data = {}
    for col in obj.__table__.columns:
        value = getattr(obj, col.name)
        data[col.name] = value.isoformat() if hasattr(value, "isoformat") else value
    return data


def _update_schema(schema_cls: Type[BaseModel]) -> Type[BaseModel]:
    """Derive a PATCH schema from the create schema: every field optional.

    ``model_dump(exclude_unset=True)`` on requests then yields exactly the
    fields the client provided, so ``PATCH`` behaves like a true partial
    update instead of requiring the whole record.
    """
    fields: dict[str, Any] = {}
    for name, f_field in schema_cls.model_fields.items():
        if name in _PROTECTED or name == "id":
            continue
        ann = f_field.annotation
        annotation = ann if get_origin(ann) is Union else Optional[ann]
        fields[name] = (annotation, None)
    return create_model(f"{schema_cls.__name__}Update", **fields)


def _register(
    resource: str,
    model: Type,
    schema_cls: Type[BaseModel],
    *,
    search_fields: tuple[str, ...] = ("burmese_name", "english_name", "code"),
    order_by: str = "display_order",
    label: str | None = None,
) -> None:
    label = label or resource
    _RESOURCES[resource] = {
        "resource": resource,
        "label": label,
        "fields": _field_meta(schema_cls),
    }

    @router.get(f"/{resource}", name=f"list_{resource}")
    def list_items(  # noqa: ANN202
        q: str | None = Query(None, description="Free-text search"),
        include_inactive: bool = Query(False),
        parent_id: int | None = Query(None),
        db: Session = Depends(get_db),
        _user: User = Depends(get_current_user),
    ):
        query = db.query(model)
        if not include_inactive:
            query = query.filter(getattr(model, "is_active") == True)  # noqa: E712
        if q:
            from sqlalchemy import or_

            clauses = [getattr(model, f).ilike(f"%{q}%") for f in search_fields if hasattr(model, f)]
            if clauses:
                query = query.filter(or_(*clauses))
        # optional parent filter for hierarchical data
        parent_fk = {
            "districts": "state_region_id",
            "townships": "district_id",
            "village-tracts": "township_id",
            "wards": "village_tract_id",
            "animal-categories": "animal_type_id",
            "breeds": "animal_type_id",
            "breeding-categories": "animal_type_id",
            "species": "animal_type_id",
        }.get(resource)
        if parent_id is not None and parent_fk:
            query = query.filter(getattr(model, parent_fk) == parent_id)
        if hasattr(model, order_by):
            query = query.order_by(getattr(model, order_by), getattr(model, "id"))
        return [_serialize(r) for r in query.all()]

    @router.get(f"/{resource}/{{item_id}}", name=f"get_{resource}")
    def get_item(item_id: int, db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
        obj = db.get(model, item_id)
        if not obj:
            raise HTTPException(status_code=404, detail=f"{label} not found")
        return _serialize(obj)

    @router.post(f"/{resource}", status_code=status.HTTP_201_CREATED, name=f"create_{resource}")
    def create_item(
        payload: schema_cls,  # type: ignore[valid-type]
        request: Request,
        db: Session = Depends(get_db),
        user: User = Depends(require_admin),
    ):
        data = _dump(payload)
        # enforce uniqueness on natural keys where present
        if "code" in data:
            existing = db.query(model).filter(getattr(model, "code") == data["code"]).first()
            if existing:
                raise HTTPException(status_code=409, detail=f"{label} with code '{data['code']}' already exists")
        obj = model(**data)
        db.add(obj)
        db.commit()
        db.refresh(obj)
        record_audit(db, action=f"{resource}.create", entity_type=resource, entity_id=obj.id,
                     actor_id=user.id, after=data, request=request, commit=True)
        return _serialize(obj)

    @router.patch(f"/{resource}/{{item_id}}", name=f"update_{resource}")
    def update_item(
        item_id: int,
        payload: _update_schema(schema_cls),  # type: ignore[valid-type]
        request: Request,
        db: Session = Depends(get_db),
        user: User = Depends(require_admin),
    ):
        obj = db.get(model, item_id)
        if not obj:
            raise HTTPException(status_code=404, detail=f"{label} not found")
        before = _serialize(obj)
        for key, value in payload.model_dump(exclude_unset=True, exclude=_PROTECTED).items():
            setattr(obj, key, value)
        db.commit()
        db.refresh(obj)
        record_audit(db, action=f"{resource}.update", entity_type=resource, entity_id=obj.id,
                     actor_id=user.id, before=before, after=_serialize(obj), request=request, commit=True)
        return _serialize(obj)

    @router.delete(f"/{resource}/{{item_id}}", name=f"deactivate_{resource}")
    def deactivate_item(
        item_id: int,
        request: Request,
        db: Session = Depends(get_db),
        user: User = Depends(require_admin),
    ):
        obj = db.get(model, item_id)
        if not obj:
            raise HTTPException(status_code=404, detail=f"{label} not found")
        if hasattr(obj, "is_active"):
            obj.is_active = False
        db.commit()
        record_audit(db, action=f"{resource}.deactivate", entity_type=resource, entity_id=item_id,
                     actor_id=user.id, request=request, commit=True)
        return {"detail": f"{label} deactivated"}


# Register every master-data resource.
_register("genders", m.Gender, GenderSchema, search_fields=("burmese_name", "english_name", "code"), label="Gender")
_register("animal-types", m.AnimalType, AnimalTypeSchema, label="Animal type")
_register("animal-categories", m.AnimalCategory, AnimalCategorySchema, label="Animal category")
_register("breeds", m.Breed, BreedSchema, label="Breed")
_register("species", m.Species, SpeciesSchema, label="Species")
_register("age-groups", m.AgeGroup, AgeGroupSchema, label="Age group")
_register("age-types", m.AgeType, AgeTypeSchema, label="Age type")
_register("breeding-categories", m.BreedingCategory, BreedingCategorySchema, label="Breeding category")
_register("state-regions", m.StateRegion, StateRegionSchema, label="State/Region")
_register("districts", m.District, DistrictSchema, label="District")
_register("townships", m.Township, TownshipSchema, label="Township")
_register("village-tracts", m.VillageTract, VillageTractSchema, label="Village tract")
_register("wards", m.Ward, WardSchema, label="Ward/Village")
_register("options", m.Option, OptionSchema, search_fields=("burmese_label", "english_label", "code"), label="Option")


@router.get("/meta")
def master_meta(_user: User = Depends(get_current_user)):
    """Describe every master-data resource and its editable fields.

    Powers the generic admin CRUD screens so the front-end never hard-codes
    field lists.
    """
    return {"resources": list(_RESOURCES.values())}


# Field ``data_binding`` values that resolve to a master-data resource. Only
# these can be reported as "used by" a form question; repeating-group row
# schemas (animal_rows / poultry_rows / breeding_rows) are defined by the app
# itself, not by a single master-data table.
_BINDING_TO_RESOURCE: dict[str, str] = {
    "gender": "genders",
    "state_region": "state-regions",
    "district": "districts",
    "township": "townships",
    "village_tract": "village-tracts",
    "ward": "wards",
    "animal_types": "animal-types",
    "animal_categories": "animal-categories",
    "species": "species",
    "age_groups": "age-groups",
    "breeding_categories": "breeding-categories",
}


@router.get("/usage")
def master_usage(db: Session = Depends(get_db), _user: User = Depends(get_current_user)):
    """Report how many questions (and how many distinct forms) use each list.

    Lets the Master Data screen show real relationships instead of guesswork.
    Questions are de-duplicated per form so re-publishing does not inflate the
    counts.
    """
    version_to_form = dict(db.query(m.FormVersion.id, m.FormVersion.form_id).all())
    seen: set[tuple[int | None, str]] = set()
    usage: dict[str, dict[str, Any]] = {}
    rows = (
        db.query(m.FormField.data_binding, m.FormField.form_version_id, m.FormField.name)
        .filter(m.FormField.data_binding.isnot(None))
        .all()
    )
    for binding, version_id, field_name in rows:
        resource = _BINDING_TO_RESOURCE.get(binding or "")
        if not resource:
            continue
        form_id = version_to_form.get(version_id)
        key = (form_id, field_name)
        if key in seen:
            continue
        seen.add(key)
        entry = usage.setdefault(resource, {"questions": 0, "forms": set()})
        entry["questions"] += 1
        entry["forms"].add(form_id)
    return {
        "usage": {
            resource: {"questions": stats["questions"], "forms": len(stats["forms"])}
            for resource, stats in usage.items()
        }
    }
