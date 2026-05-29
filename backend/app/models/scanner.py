"""Scanner model — physical sniffer device authenticated by API key."""
from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.area import Area


class Scanner(Base):
    """A scanner reports MAC hashes for the area it covers."""

    __tablename__ = "scanners"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    api_key: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    area_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("areas.id", ondelete="SET NULL"), nullable=True
    )
    last_seen: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    area: Mapped[Optional["Area"]] = relationship("Area", back_populates="scanners")
