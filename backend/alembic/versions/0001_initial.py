"""initial schema: areas, users, scanners, occupancy_logs

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-26

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "areas",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("floor", sa.Integer(), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_areas_id", "areas", ["id"])

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False, server_default="user"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_id", "users", ["id"])

    op.create_table(
        "scanners",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=True),
        sa.Column("api_key", sa.String(length=255), nullable=False),
        sa.Column(
            "area_id",
            sa.Integer(),
            sa.ForeignKey("areas.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("last_seen", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("api_key", name="uq_scanners_api_key"),
    )
    op.create_index("ix_scanners_api_key", "scanners", ["api_key"], unique=True)
    op.create_index("ix_scanners_id", "scanners", ["id"])

    op.create_table(
        "occupancy_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "area_id",
            sa.Integer(),
            sa.ForeignKey("areas.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("device_count", sa.Integer(), nullable=False),
        sa.Column("occupancy_pct", sa.Float(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column(
            "recorded_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_occupancy_logs_id", "occupancy_logs", ["id"])
    op.create_index(
        "ix_occupancy_area_recorded_desc",
        "occupancy_logs",
        ["area_id", sa.text("recorded_at DESC")],
    )


def downgrade() -> None:
    op.drop_index("ix_occupancy_area_recorded_desc", table_name="occupancy_logs")
    op.drop_index("ix_occupancy_logs_id", table_name="occupancy_logs")
    op.drop_table("occupancy_logs")

    op.drop_index("ix_scanners_id", table_name="scanners")
    op.drop_index("ix_scanners_api_key", table_name="scanners")
    op.drop_table("scanners")

    op.drop_index("ix_users_id", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")

    op.drop_index("ix_areas_id", table_name="areas")
    op.drop_table("areas")
