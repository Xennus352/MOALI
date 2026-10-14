"""Add species_id to animal_counts

Revision ID: a3f92c4d01b0
Revises: e61d735e4805
Create Date: 2026-10-13 08:15:00.000000

Additive, non-destructive change: the census form records the specific species
("မျိုး") chosen per animal row, while the pre-existing ``breed_id`` continues
to carry the generic local/cross/imported classification. Historic rows keep
their meaning (new column is nullable).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a3f92c4d01b0"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "animal_counts"
_FK = "fk_animal_counts_species_id"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {c["name"] for c in inspector.get_columns(_TABLE)}
    if "species_id" not in existing:
        op.add_column(_TABLE, sa.Column("species_id", sa.Integer(), nullable=True))
        op.create_foreign_key(_FK, _TABLE, "species", ["species_id"], ["id"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {c["name"] for c in inspector.get_columns(_TABLE)}
    if "species_id" in existing:
        op.drop_constraint(_FK, _TABLE, type_="foreignkey")
        op.drop_column(_TABLE, "species_id")