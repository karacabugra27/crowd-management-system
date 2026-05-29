"""Occupancy computation, persistence, and broadcast."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import bad_request, not_found
from app.models.area import Area
from app.models.occupancy import OccupancyLog
from app.schemas.occupancy import (
    HeatmapEntry,
    LiveOccupancy,
    OccupancyHistoryEntry,
    OccupancyResult,
    OccupancySummary,
)
from app.services.websocket_manager import manager


def classify_status(pct: float) -> str:
    """Map an occupancy percentage to a discrete status bucket."""
    if pct <= 30:
        return "empty"
    if pct <= 60:
        return "low"
    if pct <= 75:
        return "medium"
    if pct <= 90:
        return "high"
    return "full"


def compute_occupancy(device_count: int, capacity: int) -> tuple[float, str]:
    """Return `(percentage, status)` clamped to 0–100."""
    if capacity <= 0:
        raise bad_request("Area capacity must be positive")
    pct = (device_count / capacity) * 100.0
    pct = max(0.0, min(pct, 100.0))
    return round(pct, 2), classify_status(pct)


async def record_scanner_reading(
    db: AsyncSession, area_id: int, mac_hashes: List[str]
) -> OccupancyResult:
    """Persist a scanner reading and broadcast it over WebSocket.

    `device_count` is the number of **unique** hashes in `mac_hashes`.
    """
    area = await db.get(Area, area_id)
    if area is None or not area.is_active:
        raise not_found("Area")

    device_count = len(set(mac_hashes))
    pct, status = compute_occupancy(device_count, area.capacity)

    log = OccupancyLog(
        area_id=area.id,
        device_count=device_count,
        occupancy_pct=pct,
        status=status,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)

    payload = {
        "area_id": area.id,
        "area_name": area.name,
        "device_count": device_count,
        "occupancy_pct": pct,
        "status": status,
        "recorded_at": log.recorded_at.isoformat(),
    }
    await manager.broadcast(payload)

    return OccupancyResult(
        area_id=area.id,
        device_count=device_count,
        occupancy_pct=pct,
        status=status,
    )


async def _latest_log_for_area(
    db: AsyncSession, area_id: int
) -> Optional[OccupancyLog]:
    result = await db.execute(
        select(OccupancyLog)
        .where(OccupancyLog.area_id == area_id)
        .order_by(desc(OccupancyLog.recorded_at))
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_live_all(db: AsyncSession) -> List[LiveOccupancy]:
    """One latest snapshot per active area."""
    areas_q = await db.execute(select(Area).where(Area.is_active.is_(True)))
    areas = areas_q.scalars().all()
    out: List[LiveOccupancy] = []
    for area in areas:
        log = await _latest_log_for_area(db, area.id)
        out.append(
            LiveOccupancy(
                area_id=area.id,
                area_name=area.name,
                device_count=log.device_count if log else 0,
                occupancy_pct=log.occupancy_pct if log else 0.0,
                status=log.status if log else "empty",
                last_updated=log.recorded_at if log else None,
            )
        )
    return out


async def get_live_for_area(db: AsyncSession, area_id: int) -> LiveOccupancy:
    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")
    log = await _latest_log_for_area(db, area_id)
    return LiveOccupancy(
        area_id=area.id,
        area_name=area.name,
        device_count=log.device_count if log else 0,
        occupancy_pct=log.occupancy_pct if log else 0.0,
        status=log.status if log else "empty",
        last_updated=log.recorded_at if log else None,
    )


async def get_history(
    db: AsyncSession, area_id: int, hours: int = 24
) -> List[OccupancyHistoryEntry]:
    """Return logs for `area_id` within the last `hours` (DESC by time)."""
    if hours <= 0 or hours > 24 * 365:
        raise bad_request("hours must be between 1 and 8760")

    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")

    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    q = (
        select(OccupancyLog)
        .where(OccupancyLog.area_id == area_id)
        .where(OccupancyLog.recorded_at >= since)
        .order_by(desc(OccupancyLog.recorded_at))
    )
    rows = (await db.execute(q)).scalars().all()
    return [OccupancyHistoryEntry.model_validate(r) for r in rows]


async def get_heatmap(db: AsyncSession) -> List[HeatmapEntry]:
    """One geocoded point per active area, with its latest occupancy."""
    areas_q = await db.execute(select(Area).where(Area.is_active.is_(True)))
    areas = areas_q.scalars().all()
    out: List[HeatmapEntry] = []
    for area in areas:
        log = await _latest_log_for_area(db, area.id)
        out.append(
            HeatmapEntry(
                area_id=area.id,
                area_name=area.name,
                latitude=area.latitude,
                longitude=area.longitude,
                occupancy_pct=log.occupancy_pct if log else 0.0,
                status=log.status if log else "empty",
            )
        )
    return out


async def get_summary(db: AsyncSession) -> List[OccupancySummary]:
    """Per-area aggregate stats over the entire log history."""
    areas_q = await db.execute(select(Area))
    areas = areas_q.scalars().all()

    out: List[OccupancySummary] = []
    for area in areas:
        agg_q = await db.execute(
            select(
                func.coalesce(func.avg(OccupancyLog.occupancy_pct), 0.0),
                func.coalesce(func.max(OccupancyLog.occupancy_pct), 0.0),
                func.count(OccupancyLog.id),
            ).where(OccupancyLog.area_id == area.id)
        )
        avg_occ, max_occ, total = agg_q.one()

        peak_q = await db.execute(
            select(
                func.extract("hour", OccupancyLog.recorded_at).label("h"),
                func.avg(OccupancyLog.occupancy_pct).label("p"),
            )
            .where(OccupancyLog.area_id == area.id)
            .group_by("h")
            .order_by(desc("p"))
            .limit(1)
        )
        peak_row = peak_q.first()
        peak_hour = int(peak_row.h) if peak_row else None

        out.append(
            OccupancySummary(
                area_id=area.id,
                area_name=area.name,
                avg_occupancy=round(float(avg_occ), 2),
                max_occupancy=round(float(max_occ), 2),
                peak_hour=peak_hour,
                total_records=int(total),
            )
        )
    return out
