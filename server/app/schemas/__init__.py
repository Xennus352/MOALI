# backend/server/app/schemas.py
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


# ============================================================
# Field type constants
# ============================================================

SHORT_TEXT = "short_text"
LONG_TEXT = "long_text"
INTEGER = "integer"
DECIMAL = "decimal"
DATE = "date"
TIME = "time"
DATETIME = "datetime"
TELEPHONE = "telephone"
EMAIL = "email"
SINGLE_SELECT = "single_select"
MULTI_SELECT = "multi_select"
RADIO = "radio"
CHECKBOX = "checkbox"
BOOLEAN = "boolean"
NUMBER_COUNTER = "number_counter"
FILE_UPLOAD = "file_upload"
IMAGE_UPLOAD = "image_upload"
READ_ONLY = "read_only"
REPEATING_GROUP = "repeating_group"
DYNAMIC_TABLE = "dynamic_table"
GEOGRAPHIC = "geographic"
HIDDEN = "hidden"
HEADING = "heading"
PARAGRAPH = "paragraph"


# ============================================================
# Authentication Schemas
# ============================================================

class UserCreate(BaseModel):
    email: str = Field(..., description="User email address")
    password: str = Field(..., min_length=8, description="User password")
    full_name: Optional[str] = Field(None, description="Full name")
    role: str = Field("data_collector", description="User role")
    is_active: bool = Field(True, description="Whether user is active")


class UserLogin(BaseModel):
    email: str = Field(..., description="User email address")
    password: str = Field(..., description="User password")


class User(BaseModel):
    id: str
    email: str
    full_name: Optional[str] = None
    role: str
    is_active: bool
    last_login: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    refresh_token: str


# ============================================================
# Form Schemas
# ============================================================

class FormSchema(BaseModel):
    id: Optional[int] = None
    form_id: str = Field(..., max_length=50, description="Form identifier like 'livestock_census'")
    burmese_title: str = Field(..., description="Burmese form title")
    english_title: Optional[str] = Field(None, description="English form title")
    description: Optional[str] = Field(None, description="Form description")
    is_published: bool = Field(False, description="Whether the form is published")
    is_draft: bool = Field(True, description="Whether this is a draft version")
    publication_status: str = Field("draft", description="draft, published, archived")
    change_summary: Optional[str] = Field(None, description="Summary of changes from previous version")
    created_by: Optional[str] = Field(None, description="Administrator who created")
    created_at: Optional[datetime] = Field(None, description="When created")
    published_by: Optional[str] = Field(None, description="Administrator who published")
    published_at: Optional[datetime] = Field(None, description="When published")
    effective_date: Optional[datetime] = Field(None, description="When it becomes effective")
    version_number: int = Field(1, description="Version number")


class FormSectionSchema(BaseModel):
    id: Optional[int] = None
    form_version_id: int = Field(..., description="Form version ID")
    title_burmese: str = Field(..., description="Burmese section title")
    title_english: Optional[str] = Field(None, description="English section title")
    description_burmese: Optional[str] = Field(None, description="Burmese description")
    description_english: Optional[str] = Field(None, description="English description")
    display_order: int = Field(0, description="Display order within form")
    is_enabled: bool = Field(True, description="Whether section is enabled")
    is_conditional: bool = Field(False, description="Whether section is displayed conditionally")
    condition_json: Optional[str] = Field(None, description="JSON condition for conditional display")
    navigation_order: str = Field("sequential", description="How sections navigate: sequential, conditional")
    created_at: Optional[datetime] = Field(None, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class FormVersionSchema(BaseModel):
    id: Optional[int] = None
    form_id: int = Field(..., description="Form ID")
    version_number: int = Field(..., description="Version number")
    definition_json: str = Field(..., description="JSON form definition")
    definition_hash: str = Field(..., description="Hash of definition for change detection")
    publication_status: str = Field("draft", description="draft, published, archived")
    is_immutable: bool = Field(False, description="Whether this version is immutable (published)")
    change_summary: Optional[str] = Field(None, description="Summary of changes")
    created_by: Optional[str] = Field(None, description="Administrator who created")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    published_by: Optional[str] = Field(None, description="Administrator who published")
    published_at: Optional[datetime] = Field(None, description="When published")


class FormFieldSchema(BaseModel):
    id: Optional[int] = None
    form_version_id: int = Field(..., description="Form version ID")
    title_burmese: str = Field(..., description="Burmese field label")
    title_english: Optional[str] = Field(None, description="English field label")
    field_type: str = Field(..., description="Field type: short_text, long_text, integer, decimal, date, time, datetime, telephone, email, single_select, multi_select, radio, checkbox, boolean, number_counter, file_upload, image_upload, read_only, repeating_group, dynamic_table, geographic, hidden, heading, paragraph")
    name: str = Field(..., max_length=100, description="Field machine-readable identifier (stable ID)")
    placeholder_burmese: Optional[str] = Field(None, description="Burmese placeholder")
    placeholder_english: Optional[str] = Field(None, description="English placeholder")
    is_required: bool = Field(False, description="Whether field is required")
    is_enabled: bool = Field(True, description="Whether field is enabled")
    is_searchable: bool = Field(False, description="Whether field appears in searches")
    is_exportable: bool = Field(True, description="Whether field appears in exports")
    is_reportable: bool = Field(True, description="Whether field appears in reports")
    is_sensitive: bool = Field(False, description="Whether field contains sensitive data")
    is_filterable: bool = Field(False, description="Whether field can be used as a filter")
    display_order: int = Field(0, description="Display order within section")
    min_length: Optional[int] = Field(None, description="Minimum text length")
    max_length: Optional[int] = Field(None, description="Maximum text length")
    min_value: Optional[float] = Field(None, description="Minimum numeric value")
    max_value: Optional[float] = Field(None, description="Maximum numeric value")
    decimal_precision: Optional[int] = Field(None, description="Decimal precision for decimal fields")
    default_value: Optional[str] = Field(None, description="Default value as string")
    unit: Optional[str] = Field(None, description="Unit of measurement")
    associated_section_id: Optional[int] = Field(None, description="Legacy reference")
    condition_json: Optional[str] = Field(None, description="JSON condition for conditional visibility")
    option_source: Optional[str] = Field(None, description="Source of options: static, database, form_version")
    data_binding: Optional[str] = Field(None, description="Data binding reference")
    is_editable_after_submission: bool = Field(True, description="Whether field can be edited after submission")
    calculation_formula: Optional[str] = Field(None, description="Formula for calculated values")
    created_at: Optional[datetime] = Field(None, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class FieldOptionSchema(BaseModel):
    id: Optional[int] = None
    form_field_id: int = Field(..., description="Form field ID")
    option_id: int = Field(..., description="Master option ID")
    stored_value: Optional[str] = Field(None, description="Value stored in submissions")
    display_order: int = Field(0, description="Display order within this field")
    is_active: bool = Field(True, description="Whether this option is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


# ============================================================
# Master Data Schemas
# ============================================================

class GenderSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=10, description="Gender code like g01, g02, g03")
    burmese_name: str = Field(..., description="Burmese gender name")
    english_name: Optional[str] = Field(None, description="English gender name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this gender is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class AnimalTypeSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=20, description="Animal type code")
    burmese_name: str = Field(..., description="Burmese animal type name")
    english_name: Optional[str] = Field(None, description="English animal type name")
    description: Optional[str] = Field(None, description="Description")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this animal type is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class AnimalCategorySchema(BaseModel):
    id: Optional[int] = None
    animal_type_id: int = Field(..., description="Links to animal_types")
    code: str = Field(..., max_length=20, description="Category code like 'large' or 'young'")
    burmese_name: str = Field(..., description="Burmese category name")
    english_name: Optional[str] = Field(None, description="English category name")
    description: Optional[str] = Field(None, description="Description")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this category is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class OptionSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=50, description="Option code like bsID01, laID01")
    burmese_label: str = Field(..., description="Burmese label")
    english_label: Optional[str] = Field(None, description="English label")
    stored_value: Optional[str] = Field(None, description="Stored value")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this option is active")
    parent_id: Optional[int] = Field(None, description="Parent option for hierarchy")
    option_type: str = Field("simple", description="Type: state, district, township, animal, breed, age, gender")
    metadata: Optional[str] = Field(None, description="JSON metadata")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class StateRegionSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=20, description="Code like 'kaungngan', 'kyain'")
    burmese_name: str = Field(..., description="Burmese state/region name")
    english_name: Optional[str] = Field(None, description="English state/region name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this state/region is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class DistrictSchema(BaseModel):
    id: Optional[int] = None
    state_region_id: int = Field(..., description="State/Region ID")
    code: str = Field(..., max_length=20, description="District code")
    burmese_name: str = Field(..., description="Burmese district name")
    english_name: Optional[str] = Field(None, description="English district name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this district is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class TownshipSchema(BaseModel):
    id: Optional[int] = None
    district_id: int = Field(..., description="District ID")
    code: str = Field(..., max_length=20, description="Township code")
    burmese_name: str = Field(..., description="Burmese township name")
    english_name: Optional[str] = Field(None, description="English township name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this township is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class VillageTractSchema(BaseModel):
    id: Optional[int] = None
    township_id: int = Field(..., description="Township ID")
    code: str = Field(..., max_length=20, description="Village tract code")
    burmese_name: str = Field(..., description="Burmese village tract name")
    english_name: Optional[str] = Field(None, description="English village tract name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this village tract is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class WardSchema(BaseModel):
    id: Optional[int] = None
    village_tract_id: int = Field(..., description="Village tract ID")
    code: str = Field(..., max_length=20, description="Ward/village code")
    burmese_name: str = Field(..., description="Burmese ward/village name")
    english_name: Optional[str] = Field(None, description="English ward/village name")
    is_populated: bool = Field(True, description="Whether this ward has residents")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this ward is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class AgeGroupSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=50, description="Age group code")
    burmese_name: str = Field(..., description="Burmese age group name")
    english_name: Optional[str] = Field(None, description="English age group name")
    description: Optional[str] = Field(None, description="Age range description in English")
    min_age: Optional[int] = Field(None, description="Minimum age in years")
    max_age: Optional[int] = Field(None, description="Maximum age in years (null for open-ended)")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this age group is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class AgeTypeSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=20, description="Age type code like years, months, weeks")
    burmese_name: str = Field(..., description="Burmese age type name")
    english_name: Optional[str] = Field(None, description="English age type name")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this age type is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class BreedSchema(BaseModel):
    id: Optional[int] = None
    animal_type_id: int = Field(..., description="Links to animal_types")
    code: str = Field(..., max_length=20, description="Breed code like bsID01, laID01")
    burmese_name: str = Field(..., description="Burmese breed/species name")
    english_name: Optional[str] = Field(None, description="English breed/species name")
    description: Optional[str] = Field(None, description="Breed description")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this breed is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class SpeciesSchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=20, description="Species code like lsSID0101")
    burmese_name: str = Field(..., description="Burmese species name")
    english_name: Optional[str] = Field(None, description="English species name")
    animal_type_id: int = Field(..., description="Links to animal_types")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this species is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class BreedingCategorySchema(BaseModel):
    id: Optional[int] = None
    code: str = Field(..., max_length=50, description="Category code like local_cattle, local_buffalo")
    burmese_name: str = Field(..., description="Burmese category name")
    english_name: Optional[str] = Field(None, description="English category name")
    animal_type_id: int = Field(..., description="Links to animal_types")
    display_order: int = Field(0, description="Display order")
    is_active: bool = Field(True, description="Whether this category is active")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


# ============================================================
# Census Data Schemas
# ============================================================

class AnimalCountSchema(BaseModel):
    id: Optional[int] = None
    submission_id: int = Field(..., description="Submission ID")
    animal_type_id: int = Field(..., description="Animal type ID")
    breed_id: int = Field(..., description="Breed ID")
    age_group_id: Optional[int] = Field(None, description="Age group ID (nullable for flexible counting)")
    gender: str = Field(..., description="Male, Female, or Castrated")
    count: int = Field(0, description="Number of animals")
    is_total: bool = Field(False, description="Whether this is a calculated total")
    display_order: int = Field(0, description="Display order")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")


class BreedingCountSchema(BaseModel):
    id: Optional[int] = None
    submission_id: int = Field(..., description="Submission ID")
    breeding_category_id: int = Field(..., description="Breeding category ID")
    male_count: int = Field(0, description="Male count")
    female_count: int = Field(0, description="Female count")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")


class FormFieldAnswerSchema(BaseModel):
    id: Optional[int] = None
    submission_id: int = Field(..., description="Submission ID")
    form_field_id: int = Field(..., description="Form field ID")
    answer_text: Optional[str] = Field(None, description="Text answer for text fields")
    answer_integer: Optional[int] = Field(None, description="Integer answer")
    answer_decimal: Optional[float] = Field(None, description="Decimal answer")
    answer_boolean: Optional[bool] = Field(None, description="Boolean answer")
    answer_date: Optional[datetime] = Field(None, description="Date answer")
    answer_option_id: Optional[int] = Field(None, description="Selected option ID")
    answer_option_text: Optional[str] = Field(None, description="Selected option Burmese name")
    answer_option_english: Optional[str] = Field(None, description="Selected option English name")
    answer_json: Optional[str] = Field(None, description="JSON answer for complex types")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When created")
    updated_at: Optional[datetime] = Field(None, description="When last updated")


class SubmissionSchema(BaseModel):
    id: Optional[int] = None
    form_version_id: int = Field(..., description="Form version ID")
    version_number: int = Field(..., description="Form version used when submitted")
    state_region_id: Optional[int] = Field(None, description="State/Region ID")
    district_id: Optional[int] = Field(None, description="District ID")
    township_id: Optional[int] = Field(None, description="Township ID")
    village_tract_id: Optional[int] = Field(None, description="Village tract ID")
    ward_id: Optional[int] = Field(None, description="Ward/Village ID")
    household_no: str = Field(..., max_length=50, description="Household number")
    respondent_name_burmese: str = Field(..., max_length=200, description="Burmese respondent name")
    respondent_name_english: Optional[str] = Field(None, max_length=200, description="English respondent name")
    respondent_gender_id: int = Field(..., description="Respondent gender ID")
    respondent_age_group_id: int = Field(..., description="Respondent age group ID")
    respondent_education: Optional[str] = Field(None, max_length=200, description="Respondent education")
    respondent_phone: str = Field(..., max_length=20, description="Respondent phone number")
    household_head_name_burmese: str = Field(..., max_length=200, description="Burmese household head name")
    household_head_name_english: Optional[str] = Field(None, max_length=200, description="English household head name")
    household_head_gender_id: int = Field(..., description="Household head gender ID")
    household_head_age_group_id: int = Field(..., description="Household head age group ID")
    household_head_education: Optional[str] = Field(None, max_length=200, description="Household head education")
    household_head_phone: str = Field(..., max_length=20, description="Household head phone number")
    interview_date: datetime = Field(..., description="Interview date")
    has_raised_animals: bool = Field(False, description="Whether household raises livestock")
    has_poultry: bool = Field(False, description="Whether household raises poultry")
    collection_status: str = Field("pending", description="pending, under_review, approved, rejected")
    review_status: str = Field("pending", description="pending, approved, rejected")
    review_notes: Optional[str] = Field(None, description="Review notes")
    reviewed_by: Optional[str] = Field(None, description="Who reviewed")
    reviewed_at: Optional[datetime] = Field(None, description="When reviewed")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When submitted")
    updated_at: Optional[datetime] = Field(None, description="Last updated")


class SubmissionListItemSchema(BaseModel):
    id: int
    household_no: str
    respondent_name_burmese: str
    state_region_burmese: Optional[str] = None
    district_burmese: Optional[str] = None
    township_burmese: Optional[str] = None
    collection_status: str
    review_status: str
    created_at: datetime
    form_version_number: int


# ============================================================
# Dashboard Schemas
# ============================================================

class KPIDashboardSchema(BaseModel):
    totalSubmissions: int = Field(0, description="Total census submissions")
    submissionsToday: int = Field(0, description="Submissions received today")
    submissionsThisWeek: int = Field(0, description="Submissions received this week")
    totalUsers: int = Field(0, description="Total registered users")
    activeCollectors: int = Field(0, description="Active data collectors")
    pendingReview: int = Field(0, description="Submissions under review")
    approvedSubmissions: int = Field(0, description="Approved submissions")
    rejectedSubmissions: int = Field(0, description="Rejected submissions")
    configuredFields: int = Field(0, description="Configured census fields")
    formPublicationStatus: Dict[str, int] = Field(default_factory=dict, description="Form publication status breakdown")


# ============================================================
# Notification and Audit Schemas
# ============================================================

class NotificationSchema(BaseModel):
    id: int
    title_burmese: str = ""
    title_english: Optional[str] = None
    message_burmese: str = ""
    message_english: Optional[str] = None
    type: str = "info"
    related_entity_type: Optional[str] = None
    related_entity_id: Optional[int] = None
    recipient_role: Optional[str] = None
    is_read: bool = False
    created_at: datetime
    created_by: Optional[str] = None


class AuditLogSchema(BaseModel):
    id: int
    actor_id: Optional[str] = None
    action: str = ""
    entity_type: str = ""
    entity_id: Optional[int] = None
    entity_before: Optional[str] = Field(None, description="JSON state before change")
    entity_after: Optional[str] = Field(None, description="JSON state after change")
    metadata: Optional[str] = Field(None, description="Additional metadata as JSON")
    ip_address: Optional[str] = Field(None, description="Client IP address")
    user_agent: Optional[str] = Field(None, description="User agent string")
    created_at: datetime
