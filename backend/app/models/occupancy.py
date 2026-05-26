"""OccupancyLog model — time-series record of device counts per area."""
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.area import Area


class OccupancyLog(Base):
    """A single occupancy snapshot reported by a scanner."""

    __tablename__ = "occupancy_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    area_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("areas.id", ondelete="CASCADE"),
        nullable=False,
    )
    device_count: Mapped[int] = mapped_column(Integer, nullable=False)
    occupancy_pct: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    area: Mapped["Area"] = relationship("Area", back_populates="occupancy_logs")

    __table_args__ = (
        Index(
            "ix_occupancy_area_recorded_desc",
            "area_id",
            "recorded_at",
        ),
    )
