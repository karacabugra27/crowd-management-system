"""/api/occupancy — live, historical, and aggregate occupancy queries."""
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.occupancy import (
    HeatmapEntry,
    LiveOccupancy,
    OccupancyHistoryEntry,
    OccupancySummary,
)
from app.services import occupancy_service

router = APIRouter(prefix="/api/occupancy", tags=["occupancy"])


@router.get(
    "/live",
    response_model=List[LiveOccupancy],
    summary="Latest occupancy for every active area",
)
async def live_all(db: AsyncSession = Depends(get_db)) -> List[LiveOccupancy]:
    return await occupancy_service.get_live_all(db)


@router.get(
    "/live/{area_id}",
    response_model=LiveOccupancy,
    summary="Latest occupancy for a single area",
)
async def live_one(
    area_id: int, db: AsyncSession = Depends(get_db)
) -> LiveOccupancy:
    return await occupancy_service.get_live_for_area(db, area_id)


@router.get(
    "/history/{area_id}",
    response_model=List[OccupancyHistoryEntry],
    summary="Occupancy log entries for the last N hours",
)
async def history(
    area_id: int,
    hours: int = Query(default=24, ge=1, le=8760),
    db: AsyncSession = Depends(get_db),
) -> List[OccupancyHistoryEntry]:
    return await occupancy_service.get_history(db, area_id, hours)


@router.get(
    "/heatmap",
    response_model=List[HeatmapEntry],
    summary="Geocoded occupancy points for map rendering",
)
async def heatmap(db: AsyncSession = Depends(get_db)) -> List[HeatmapEntry]:
    return await occupancy_service.get_heatmap(db)


@router.get(
    "/summary",
    response_model=List[OccupancySummary],
    summary="Per-area aggregate statistics",
)
async def summary(db: AsyncSession = Depends(get_db)) -> List[OccupancySummary]:
    return await occupancy_service.get_summary(db)
