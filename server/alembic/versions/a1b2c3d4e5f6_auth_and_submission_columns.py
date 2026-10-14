"""Auth hardening + submission ownership columns

Revision ID: a1b2c3d4e5f6
Revises: e61d735e4805
Create Date: 2026-10-13 12:30:00.000000

Additive, idempotent migration. Every operation is guarded by an inspector
check so it is safe to apply whether the database was created by Alembic or by
``Base.metadata.create_all()`` (as the original development database was).
No existing column is dropped or renamed.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "e61d735e4805"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if table not in insp.get_table_names():
        return False
    return column in {c["name"] for c in insp.get_columns(table)}


def _add(table: str, column: sa.Column) -> None:
    if not _has_column(table, column.name):
        op.add_column(table, column)


def upgrade() -> None:
    # --- users: session revocation + login lockout -----------------------
    _add("users", sa.Column("session_version", sa.Integer(), nullable=False, server_default="0"))
    _add("users", sa.Column("last_login_at", sa.DateTime(), nullable=True))
    _add("users", sa.Column("failed_login_attempts", sa.Integer(), nullable=False, server_default="0"))
    _add("users", sa.Column("locked_until", sa.DateTime(), nullable=True))

    # --- submissions: who created the record + interviewer ----------------
    _add("submissions", sa.Column("interviewer_name", sa.String(length=200), nullable=True))
    _add("submissions", sa.Column("interviewer_phone", sa.String(length=20), nullable=True))
    _add("submissions", sa.Column("created_by_user_id", sa.Integer(), nullable=True))

    # --- species: link to concrete animal category ------------------------
    _add("species", sa.Column("animal_category_code", sa.String(length=30), nullable=True))

    # --- foreign keys -----------------------------------------------------
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if "submissions" in insp.get_table_names():
        fks = {fk["name"] for fk in insp.get_foreign_keys("submissions")}
        if "fk_submissions_created_by_user" not in fks:
            try:
                op.create_foreign_key(
                    "fk_submissions_created_by_user",
                    "submissions",
                    "users",
                    ["created_by_user_id"],
                    ["id"],
                )
            except Exception:
                pass


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if "submissions" in insp.get_table_names():
        fks = {fk["name"] for fk in insp.get_foreign_keys("submissions")}
        if "fk_submissions_created_by_user" in fks:
            op.drop_constraint("fk_submissions_created_by_user", "submissions", type_="foreignkey")

    for table, column in [
        ("submissions", "created_by_user_id"),
        ("submissions", "interviewer_phone"),
        ("submissions", "interviewer_name"),
        ("users", "locked_until"),
        ("users", "failed_login_attempts"),
        ("users", "last_login_at"),
        ("users", "session_version"),
        ("species", "animal_category_code"),
    ]:
        if _has_column(table, column):
            op.drop_column(table, column)
