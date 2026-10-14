# backend/server/app/schemas/census.py
"""Request/response schemas for census submissions and the review workflow."""
from __future__ import annotations

from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator

ReviewAction = Literal["submit", "start_review", "approve", "reject", "return", "reopen"]


class AnimalCountIn(BaseModel):
    animal_type_id: int
    species_id: Optional[int] = None
    breed_id: Optional[int] = None
    age_group_id: Optional[int] = None
    gender: Literal["male", "female", "castrated", "total"]
    count: int = Field(0, ge=0)


class BreedingCountIn(BaseModel):
    breeding_category_id: int
    male_count: int = Field(0, ge=0)
    female_count: int = Field(0, ge=0)


class SubmissionCreate(BaseModel):
    form_version_id: Optional[int] = None
    state_region_id: Optional[int] = None
    district_id: Optional[int] = None
    township_id: Optional[int] = None
    village_tract_id: Optional[int] = None
    ward_id: Optional[int] = None

    household_no: str = Field(..., min_length=1, max_length=50)
    respondent_name_burmese: Optional[str] = Field(None, max_length=200)
    respondent_name_english: Optional[str] = Field(None, max_length=200)
    respondent_gender_id: Optional[int] = None
    respondent_age: Optional[int] = Field(None, ge=0, le=130)
    respondent_age_group_id: Optional[int] = None
    respondent_education: Optional[str] = Field(None, max_length=200)
    respondent_phone: Optional[str] = Field(None, max_length=20)

    household_head_name_burmese: Optional[str] = Field(None, max_length=200)
    household_head_name_english: Optional[str] = Field(None, max_length=200)
    household_head_gender_id: Optional[int] = None
    household_head_age: Optional[int] = Field(None, ge=0, le=130)
    household_head_age_group_id: Optional[int] = None
    household_head_education: Optional[str] = Field(None, max_length=200)
    household_head_phone: Optional[str] = Field(None, max_length=20)

    interview_date: date
    interviewer_name: Optional[str] = Field(None, max_length=200)
    interviewer_phone: Optional[str] = Field(None, max_length=20)

    has_raised_animals: bool = False
    has_poultry: bool = False

    animal_counts: list[AnimalCountIn] = Field(default_factory=list)
    breeding_counts: list[BreedingCountIn] = Field(default_factory=list)

    # Admin-authored form fields that are not part of the fixed submission
    # schema. Stored as typed `FormFieldAnswer` rows keyed by field name so a
    # change to the live form definition does not require a database migration.
    additional_data: Optional[dict] = None

    # If true, bypass duplicate detection for an intentional re-survey.
    allow_duplicate: bool = False

    @field_validator("interview_date")
    @classmethod
    def no_future_date(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("interview_date cannot be in the future")
        return v


class SubmissionUpdate(BaseModel):
    household_no: Optional[str] = Field(None, max_length=50)
    respondent_name_burmese: Optional[str] = Field(None, max_length=200)
    respondent_gender_id: Optional[int] = None
    respondent_age: Optional[int] = Field(None, ge=0, le=130)
    respondent_age_group_id: Optional[int] = None
    respondent_education: Optional[str] = Field(None, max_length=200)
    respondent_phone: Optional[str] = Field(None, max_length=20)
    household_head_name_burmese: Optional[str] = Field(None, max_length=200)
    household_head_gender_id: Optional[int] = None
    household_head_age: Optional[int] = Field(None, ge=0, le=130)
    household_head_age_group_id: Optional[int] = None
    household_head_education: Optional[str] = Field(None, max_length=200)
    household_head_phone: Optional[str] = Field(None, max_length=20)
    interview_date: Optional[date] = None
    interviewer_name: Optional[str] = Field(None, max_length=200)
    interviewer_phone: Optional[str] = Field(None, max_length=20)
    has_raised_animals: Optional[bool] = None
    has_poultry: Optional[bool] = None
    animal_counts: Optional[list[AnimalCountIn]] = None
    breeding_counts: Optional[list[BreedingCountIn]] = None
    additional_data: Optional[dict] = None


class ReviewRequest(BaseModel):
    action: ReviewAction
    notes: Optional[str] = Field(None, max_length=2000)


class ReviewEventOut(BaseModel):
    id: int
    actor_id: Optional[str] = None
    action: str
    entity_type: str
    entity_id: Optional[int] = None
    metadata: Optional[str] = None
    created_at: datetime
