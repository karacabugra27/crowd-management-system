"""/api/admin — dashboard stats and scanner management."""
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import not_found
from app.core.security import generate_api_key
from app.database import get_db
from app.dependencies import get_current_admin
from app.models.area import Area
from app.models.occupancy import OccupancyLog
from app.models.scanner import Scanner
from app.models.user import User
from app.schemas.admin import AreaOccupancyRef, DashboardStats
from app.schemas.occupancy import OccupancyHistoryEntry
from app.schemas.scanner import ScannerCreate, ScannerCreated, ScannerRead
from app.services import occupancy_service

router = APIRouter(
    prefix="/api/admin",
    tags=["admin"],
    dependencies=[Depends(get_current_admin)],
)


@router.get("/dashboard", response_model=DashboardStats, summary="Top-line stats")
async def dashboard(db: AsyncSession = Depends(get_db)) -> DashboardStats:
    total_areas = (await db.execute(select(func.count(Area.id)))).scalar_one()
    active_areas = (
        await db.execute(
            select(func.count(Area.id)).where(Area.is_active.is_(True))
        )
    ).scalar_one()
    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()

    live = await occupancy_service.get_live_all(db)
    if live:
        avg_occupancy = round(
            sum(item.occupancy_pct for item in live) / len(live), 2
        )
        busiest = max(live, key=lambda i: i.occupancy_pct)
        emptiest = min(live, key=lambda i: i.occupancy_pct)
        busiest_ref: Optional[AreaOccupancyRef] = AreaOccupancyRef(
            area_id=busiest.area_id,
            area_name=busiest.area_name,
            occupancy_pct=busiest.occupancy_pct,
        )
        emptiest_ref: Optional[AreaOccupancyRef] = AreaOccupancyRef(
            area_id=emptiest.area_id,
            area_name=emptiest.area_name,
            occupancy_pct=emptiest.occupancy_pct,
        )
    else:
        avg_occupancy = 0.0
        busiest_ref = None
        emptiest_ref = None

    return DashboardStats(
        total_areas=int(total_areas),
        active_areas=int(active_areas),
        total_users=int(total_users),
        avg_occupancy=avg_occupancy,
        busiest_area=busiest_ref,
        emptiest_area=emptiest_ref,
    )


@router.get(
    "/scanners",
    response_model=List[ScannerRead],
    summary="List all registered scanners",
)
async def list_scanners(db: AsyncSession = Depends(get_db)) -> List[ScannerRead]:
    result = await db.execute(select(Scanner).order_by(Scanner.id))
    return [ScannerRead.model_validate(s) for s in result.scalars().all()]


@router.post(
    "/scanners",
    response_model=ScannerCreated,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new scanner and return its API key (shown once)",
)
async def create_scanner(
    payload: ScannerCreate, db: AsyncSession = Depends(get_db)
) -> ScannerCreated:
    if payload.area_id is not None:
        area = await db.get(Area, payload.area_id)
        if area is None:
            raise not_found("Area")

    api_key = generate_api_key()
    scanner = Scanner(
        name=payload.name,
        api_key=api_key,
        area_id=payload.area_id,
        is_active=True,
    )
    db.add(scanner)
    await db.commit()
    await db.refresh(scanner)
    return ScannerCreated(id=scanner.id, name=scanner.name, api_key=api_key)


@router.delete(
    "/scanners/{scanner_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a scanner",
)
async def delete_scanner(
    scanner_id: int, db: AsyncSession = Depends(get_db)
) -> None:
    scanner = await db.get(Scanner, scanner_id)
    if scanner is None:
        raise not_found("Scanner")
    await db.delete(scanner)
    await db.commit()


@router.get(
    "/logs",
    response_model=List[OccupancyHistoryEntry],
    summary="Recent occupancy log entries (optionally filtered by area)",
)
async def list_logs(
    area_id: Optional[int] = Query(default=None, gt=0),
    limit: int = Query(default=100, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
) -> List[OccupancyHistoryEntry]:
    q = select(OccupancyLog).order_by(desc(OccupancyLog.recorded_at))
    if area_id is not None:
        q = q.where(OccupancyLog.area_id == area_id)
    q = q.limit(limit)
    rows = (await db.execute(q)).scalars().all()
    return [OccupancyHistoryEntry.model_validate(r) for r in rows]
