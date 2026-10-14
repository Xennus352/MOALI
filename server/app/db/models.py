from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Boolean,
    Text,
    ForeignKey,
    Date as DateType,
    Float,
    UniqueConstraint,
    Index,
)
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime, timezone


def _utcnow():
    return datetime.now(timezone.utc)


Base = declarative_base()


# ============================================================
# Reference / master data
# ============================================================

class Gender(Base):
    __tablename__ = "genders"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(10), unique=True, nullable=False)
    burmese_name = Column(String(100), nullable=False)
    english_name = Column(String(100), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class AnimalType(Base):
    __tablename__ = "animal_types"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(20), unique=True, nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    description = Column(String(300))
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    categories = relationship("AnimalCategory", back_populates="animal_type")
    breeds = relationship("Breed", back_populates="animal_type")
    species = relationship("Species", back_populates="animal_type")
    breeding_categories = relationship("BreedingCategory", back_populates="animal_type")


class AnimalCategory(Base):
    """Concrete animal category (e.g. ဒေသနွား / local cattle).

    In the source workbook these are the ``largeAnimals`` / ``youngAnimals`` /
    ``liveStock`` / ``breedingStock`` rows.
    """
    __tablename__ = "animal_categories"
    id = Column(Integer, primary_key=True, index=True)
    animal_type_id = Column(Integer, ForeignKey("animal_types.id"), nullable=False)
    code = Column(String(20), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    description = Column(String(300), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    animal_type = relationship("AnimalType", back_populates="categories")

    __table_args__ = (UniqueConstraint("animal_type_id", "code", name="uq_category_type_code"),)


class Option(Base):
    __tablename__ = "options"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False)
    burmese_label = Column(String(200), nullable=False)
    english_label = Column(String(200), nullable=True)
    stored_value = Column(String(100), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    parent_id = Column(Integer, ForeignKey("options.id"), nullable=True)
    option_type = Column(String(30), default="simple")
    metadata = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class StateRegion(Base):
    __tablename__ = "state_regions"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), nullable=False, unique=True)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    districts = relationship("District", back_populates="state_region")


class District(Base):
    __tablename__ = "districts"
    id = Column(Integer, primary_key=True, index=True)
    state_region_id = Column(Integer, ForeignKey("state_regions.id"), nullable=False)
    code = Column(String(50), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    state_region = relationship("StateRegion", back_populates="districts")
    townships = relationship("Township", back_populates="district")


class Township(Base):
    __tablename__ = "townships"
    id = Column(Integer, primary_key=True, index=True)
    district_id = Column(Integer, ForeignKey("districts.id"), nullable=False)
    code = Column(String(50), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    district = relationship("District", back_populates="townships")
    village_tracts = relationship("VillageTract", back_populates="township")


class VillageTract(Base):
    __tablename__ = "village_tracts"
    id = Column(Integer, primary_key=True, index=True)
    township_id = Column(Integer, ForeignKey("townships.id"), nullable=False)
    code = Column(String(50), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    township = relationship("Township", back_populates="village_tracts")
    wards = relationship("Ward", back_populates="village_tract")


class Ward(Base):
    __tablename__ = "wards"
    id = Column(Integer, primary_key=True, index=True)
    village_tract_id = Column(Integer, ForeignKey("village_tracts.id"), nullable=False)
    code = Column(String(50), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    is_populated = Column(Boolean, default=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    village_tract = relationship("VillageTract", back_populates="wards")


class AgeGroup(Base):
    __tablename__ = "age_groups"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), nullable=False, unique=True)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    description = Column(String(300), nullable=True)
    min_age = Column(Integer, nullable=True)
    max_age = Column(Integer, nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class AgeType(Base):
    __tablename__ = "age_types"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(20), nullable=False, unique=True)
    burmese_name = Column(String(100), nullable=False)
    english_name = Column(String(100), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class Breed(Base):
    __tablename__ = "breeds"
    id = Column(Integer, primary_key=True, index=True)
    animal_type_id = Column(Integer, ForeignKey("animal_types.id"), nullable=False)
    code = Column(String(30), nullable=False)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    description = Column(String(300), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    animal_type = relationship("AnimalType", back_populates="breeds")


class Species(Base):
    __tablename__ = "species"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(30), nullable=False, unique=True)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    animal_type_id = Column(Integer, ForeignKey("animal_types.id"), nullable=False)
    # Optional link to the concrete animal category (large/young/poultry)
    animal_category_code = Column(String(30), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    animal_type = relationship("AnimalType", back_populates="species")


class BreedingCategory(Base):
    __tablename__ = "breeding_categories"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), nullable=False, unique=True)
    burmese_name = Column(String(200), nullable=False)
    english_name = Column(String(200), nullable=True)
    animal_type_id = Column(Integer, ForeignKey("animal_types.id"), nullable=False)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    animal_type = relationship("AnimalType", back_populates="breeding_categories")


# ============================================================
# Forms
# ============================================================

class Form(Base):
    __tablename__ = "forms"
    id = Column(Integer, primary_key=True, index=True)
    form_id = Column(String(50), unique=True, nullable=False)
    burmese_title = Column(String(500), nullable=False)
    english_title = Column(String(500), nullable=True)
    description = Column(Text, nullable=True)
    is_published = Column(Boolean, default=False)
    is_draft = Column(Boolean, default=True)
    publication_status = Column(String(20), default="draft")
    change_summary = Column(Text, nullable=True)
    created_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    published_by = Column(String(100), nullable=True)
    published_at = Column(DateTime, nullable=True)
    effective_date = Column(DateTime, nullable=True)
    version_number = Column(Integer, default=1)

    form_versions = relationship(
        "FormVersion", back_populates="form", cascade="all, delete-orphan"
    )
    submissions = relationship("Submission", back_populates="form")


class FormVersion(Base):
    __tablename__ = "form_versions"
    id = Column(Integer, primary_key=True, index=True)
    form_id = Column(Integer, ForeignKey("forms.id"), nullable=False)
    version_number = Column(Integer, nullable=False)
    definition_json = Column(Text, nullable=False)
    definition_hash = Column(String(64), nullable=False)
    publication_status = Column(String(20), default="draft")
    is_immutable = Column(Boolean, default=False)
    change_summary = Column(Text, nullable=True)
    created_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    published_by = Column(String(100), nullable=True)
    published_at = Column(DateTime, nullable=True)

    form = relationship("Form", back_populates="form_versions")
    submissions = relationship("Submission", back_populates="form_version")
    form_sections = relationship(
        "FormSection", back_populates="form_version", cascade="all, delete-orphan"
    )
    form_fields = relationship(
        "FormField", back_populates="form_version", cascade="all, delete-orphan"
    )


class FormSection(Base):
    __tablename__ = "form_sections"
    id = Column(Integer, primary_key=True, index=True)
    form_version_id = Column(Integer, ForeignKey("form_versions.id"), nullable=False)
    title_burmese = Column(String(200), nullable=False)
    title_english = Column(String(200), nullable=True)
    description_burmese = Column(String(300), nullable=True)
    description_english = Column(String(300), nullable=True)
    display_order = Column(Integer, default=0)
    is_enabled = Column(Boolean, default=True)
    is_conditional = Column(Boolean, default=False)
    condition_json = Column(Text, nullable=True)
    navigation_order = Column(String(20), default="sequential")
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    form_version = relationship("FormVersion", back_populates="form_sections")


class FormField(Base):
    __tablename__ = "form_fields"
    id = Column(Integer, primary_key=True, index=True)
    form_version_id = Column(Integer, ForeignKey("form_versions.id"), nullable=False)
    title_burmese = Column(String(200), nullable=False)
    title_english = Column(String(200), nullable=True)
    field_type = Column(String(50), nullable=False)
    name = Column(String(100), nullable=False)
    placeholder_burmese = Column(String(200), nullable=True)
    placeholder_english = Column(String(200), nullable=True)
    is_required = Column(Boolean, default=False)
    is_enabled = Column(Boolean, default=True)
    is_searchable = Column(Boolean, default=False)
    is_exportable = Column(Boolean, default=True)
    is_reportable = Column(Boolean, default=True)
    is_sensitive = Column(Boolean, default=False)
    is_filterable = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    min_length = Column(Integer, nullable=True)
    max_length = Column(Integer, nullable=True)
    min_value = Column(Integer, nullable=True)
    max_value = Column(Integer, nullable=True)
    decimal_precision = Column(Integer, nullable=True)
    default_value = Column(String(500), nullable=True)
    unit = Column(String(50), nullable=True)
    associated_section_id = Column(Integer, nullable=True)
    condition_json = Column(Text, nullable=True)
    option_source = Column(String(30), default="static")
    data_binding = Column(String(100), nullable=True)
    is_editable_after_submission = Column(Boolean, default=True)
    calculation_formula = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    form_version = relationship("FormVersion", back_populates="form_fields")

    __table_args__ = (Index("ix_form_fields_version_name", "form_version_id", "name"),)


class FieldOption(Base):
    __tablename__ = "field_options"
    id = Column(Integer, primary_key=True, index=True)
    form_field_id = Column(Integer, ForeignKey("form_fields.id"), nullable=False)
    option_id = Column(Integer, ForeignKey("options.id"), nullable=False)
    stored_value = Column(String(100), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow)


# ============================================================
# Census data
# ============================================================

class Submission(Base):
    __tablename__ = "submissions"
    id = Column(Integer, primary_key=True, index=True)
    form_version_id = Column(Integer, ForeignKey("form_versions.id"), nullable=False)
    form_id = Column(Integer, ForeignKey("forms.id"), nullable=True)
    version_number = Column(Integer, nullable=False)
    state_region_id = Column(Integer, ForeignKey("state_regions.id"), nullable=True)
    district_id = Column(Integer, ForeignKey("districts.id"), nullable=True)
    township_id = Column(Integer, ForeignKey("townships.id"), nullable=True)
    village_tract_id = Column(Integer, ForeignKey("village_tracts.id"), nullable=True)
    ward_id = Column(Integer, ForeignKey("wards.id"), nullable=True)
    household_no = Column(String(50), nullable=False)
    respondent_name_burmese = Column(String(200), nullable=True)
    respondent_name_english = Column(String(200), nullable=True)
    respondent_gender_id = Column(Integer, ForeignKey("genders.id"), nullable=True)
    respondent_age = Column(Integer, nullable=True)
    respondent_age_group_id = Column(Integer, ForeignKey("age_groups.id"), nullable=True)
    respondent_education = Column(String(200), nullable=True)
    respondent_phone = Column(String(20), nullable=True)
    household_head_name_burmese = Column(String(200), nullable=True)
    household_head_name_english = Column(String(200), nullable=True)
    household_head_gender_id = Column(Integer, ForeignKey("genders.id"), nullable=True)
    household_head_age = Column(Integer, nullable=True)
    household_head_age_group_id = Column(Integer, ForeignKey("age_groups.id"), nullable=True)
    household_head_education = Column(String(200), nullable=True)
    household_head_phone = Column(String(20), nullable=True)
    interview_date = Column(DateType, nullable=False)
    interviewer_name = Column(String(200), nullable=True)
    interviewer_phone = Column(String(20), nullable=True)
    has_raised_animals = Column(Boolean, default=False)
    has_poultry = Column(Boolean, default=False)
    collection_status = Column(String(20), default="pending")
    review_status = Column(String(20), default="pending")
    review_notes = Column(Text, nullable=True)
    reviewed_by = Column(String(100), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    form_version = relationship("FormVersion", back_populates="submissions")
    form = relationship("Form", back_populates="submissions")
    state_region = relationship("StateRegion")
    district = relationship("District")
    township = relationship("Township")
    village_tract = relationship("VillageTract")
    ward = relationship("Ward")
    respondent_gender = relationship("Gender", foreign_keys=[respondent_gender_id])
    respondent_age_group = relationship("AgeGroup", foreign_keys=[respondent_age_group_id])
    household_head_gender = relationship("Gender", foreign_keys=[household_head_gender_id])
    household_head_age_group = relationship("AgeGroup", foreign_keys=[household_head_age_group_id])
    animal_counts = relationship(
        "AnimalCount", back_populates="submission", cascade="all, delete-orphan"
    )
    breeding_counts = relationship(
        "BreedingCount", back_populates="submission", cascade="all, delete-orphan"
    )
    form_field_answers = relationship(
        "FormFieldAnswer", back_populates="submission", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_submissions_region_township", "state_region_id", "township_id"),
        Index("ix_submissions_status", "collection_status", "review_status"),
    )


class AnimalCount(Base):
    __tablename__ = "animal_counts"
    id = Column(Integer, primary_key=True, index=True)
    submission_id = Column(Integer, ForeignKey("submissions.id"), nullable=False)
    animal_type_id = Column(Integer, ForeignKey("animal_types.id"), nullable=False)
    species_id = Column(Integer, ForeignKey("species.id"), nullable=True)
    breed_id = Column(Integer, ForeignKey("breeds.id"), nullable=True)
    age_group_id = Column(Integer, ForeignKey("age_groups.id"), nullable=True)
    gender = Column(String(20), nullable=False)
    count = Column(Integer, default=0)
    is_total = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime, default=_utcnow)

    submission = relationship("Submission", back_populates="animal_counts")
    animal_type = relationship("AnimalType")
    species = relationship("Species")
    breed = relationship("Breed")
    age_group = relationship("AgeGroup")


class BreedingCount(Base):
    __tablename__ = "breeding_counts"
    id = Column(Integer, primary_key=True, index=True)
    submission_id = Column(Integer, ForeignKey("submissions.id"), nullable=False)
    breeding_category_id = Column(Integer, ForeignKey("breeding_categories.id"), nullable=False)
    male_count = Column(Integer, default=0)
    female_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=_utcnow)

    submission = relationship("Submission", back_populates="breeding_counts")
    breeding_category = relationship("BreedingCategory")


class FormFieldAnswer(Base):
    __tablename__ = "form_field_answers"
    id = Column(Integer, primary_key=True, index=True)
    submission_id = Column(Integer, ForeignKey("submissions.id"), nullable=False)
    form_field_id = Column(Integer, ForeignKey("form_fields.id"), nullable=False)
    answer_text = Column(Text, nullable=True)
    answer_integer = Column(Integer, nullable=True)
    answer_decimal = Column(Float, nullable=True)
    answer_boolean = Column(Boolean, nullable=True)
    answer_date = Column(DateType, nullable=True)
    answer_option_id = Column(Integer, ForeignKey("options.id"), nullable=True)
    answer_option_text = Column(String(200), nullable=True)
    answer_option_english = Column(String(200), nullable=True)
    answer_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow)

    submission = relationship("Submission", back_populates="form_field_answers")
    form_field = relationship("FormField")


# ============================================================
# System
# ============================================================

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    title_burmese = Column(String(200), nullable=False)
    title_english = Column(String(200), nullable=True)
    message_burmese = Column(Text, nullable=False)
    message_english = Column(Text, nullable=True)
    type = Column(String(20), default="info")
    related_entity_type = Column(String(50), nullable=True)
    related_entity_id = Column(Integer, nullable=True)
    recipient_role = Column(String(50), nullable=True)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_utcnow)
    created_by = Column(String(100), nullable=True)


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    actor_id = Column(String(100), nullable=True)
    action = Column(String(100), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(Integer, nullable=True)
    entity_before = Column(Text, nullable=True)
    entity_after = Column(Text, nullable=True)
    metadata = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=_utcnow)


# ============================================================
# Authentication
# ============================================================

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255), nullable=True)
    role = Column(String(50), default="user")  # admin, reviewer, enumerator, analyst, user
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    # Bumping this invalidates every previously issued session cookie.
    session_version = Column(Integer, default=0, nullable=False)
    last_login_at = Column(DateTime, nullable=True)
    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class OAuthAccount(Base):
    __tablename__ = "oauth_accounts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    provider = Column(String(50), nullable=False)
    provider_user_id = Column(String(100), nullable=False)
    provider_username = Column(String(100), nullable=True)
    access_token = Column(Text, nullable=True)
    refresh_token = Column(Text, nullable=True)
    scope = Column(String(200), nullable=True)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_oauth_provider_user"),
    )
