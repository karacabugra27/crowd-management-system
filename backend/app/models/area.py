"""Area model — a physical zone (room/floor/section) being monitored."""
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import Boolean, DateTime, Float, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.occupancy import OccupancyLog
    from app.models.scanner import Scanner


class Area(Base):
    """Represents a monitored area with a maximum capacity."""

    __tablename__ = "areas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    floor: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    occupancy_logs: Mapped[List["OccupancyLog"]] = relationship(
        "OccupancyLog",
        back_populates="area",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    scanners: Mapped[List["Scanner"]] = relationship(
        "Scanner",
        back_populates="area",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
