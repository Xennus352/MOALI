"""Widen geography ``code`` columns

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-10-13 13:25:00.000000

Village-tract and ward codes are derived from their parent township code, so
they can exceed the original 20 characters. Widen the geography ``code``
columns to 50 characters. Purely a widening operation: existing values are
preserved.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLES = ["state_regions", "districts", "townships", "village_tracts", "wards"]


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    existing_tables = set(insp.get_table_names())
    for table in _TABLES:
        if table not in existing_tables:
            continue
        columns = {c["name"]: c for c in insp.get_columns(table)}
        code = columns.get("code")
        if code is None:
            continue
        if isinstance(code["type"], sa.String) and (code["type"].length or 0) >= 50:
            continue
        op.alter_column(
            table,
            "code",
            existing_type=sa.String(length=code["type"].length or 20),
            type_=sa.String(length=50),
            existing_nullable=code.get("nullable", False),
        )


def downgrade() -> None:
    # Widening is not reversed: shortening could truncate valid data.
    pass
