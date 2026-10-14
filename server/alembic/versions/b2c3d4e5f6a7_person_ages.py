"""Household person ages + nullable person fields on submissions

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-10-13 13:10:00.000000

The census form (myform.html) records the respondent's and household head's
age as a plain integer (as in the ``personCV`` sheet of DB Design.xlsx), and
gender as an optional lookup. This migration adds the two integer age columns
and relaxes the person-related columns to nullable so a submission can be
recorded even when a particular detail is missing.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_TABLE = "submissions"
_NULLABLE_COLUMNS = [
    "respondent_name_burmese",
    "respondent_gender_id",
    "respondent_age_group_id",
    "respondent_phone",
    "household_head_name_burmese",
    "household_head_gender_id",
    "household_head_age_group_id",
    "household_head_phone",
]


def _has_column(insp, table: str, column: str) -> bool:
    if table not in insp.get_table_names():
        return False
    return column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if _TABLE not in insp.get_table_names():
        return

    if not _has_column(insp, _TABLE, "respondent_age"):
        op.add_column(_TABLE, sa.Column("respondent_age", sa.Integer(), nullable=True))
    if not _has_column(insp, _TABLE, "household_head_age"):
        op.add_column(_TABLE, sa.Column("household_head_age", sa.Integer(), nullable=True))

    existing = {c["name"]: c for c in insp.get_columns(_TABLE)}
    for column in _NULLABLE_COLUMNS:
        if column in existing and not existing[column].get("nullable", True):
            try:
                op.alter_column(_TABLE, column, existing_type=existing[column]["type"],
                                existing_nullable=False, nullable=True)
            except Exception:
                # Already nullable or the dialect does not support the change.
                pass


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    for column in ("household_head_age", "respondent_age"):
        if _has_column(insp, _TABLE, column):
            op.drop_column(_TABLE, column)
