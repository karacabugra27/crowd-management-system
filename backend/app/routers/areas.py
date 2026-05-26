"""/api/areas — CRUD for monitored zones."""
from typing import List

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import not_found
from app.database import get_db
from app.dependencies import get_current_admin
from app.models.area import Area
from app.models.user import User
from app.schemas.area import AreaCreate, AreaRead, AreaUpdate

router = APIRouter(prefix="/api/areas", tags=["areas"])


@router.get("/", response_model=List[AreaRead], summary="List all areas")
async def list_areas(db: AsyncSession = Depends(get_db)) -> List[AreaRead]:
    result = await db.execute(select(Area).order_by(Area.id))
    return [AreaRead.model_validate(a) for a in result.scalars().all()]


@router.get("/{area_id}", response_model=AreaRead, summary="Get a single area")
async def get_area(area_id: int, db: AsyncSession = Depends(get_db)) -> AreaRead:
    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")
    return AreaRead.model_validate(area)


@router.post(
    "/",
    response_model=AreaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new area (admin)",
)
async def create_area(
    payload: AreaCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> AreaRead:
    area = Area(**payload.model_dump())
    db.add(area)
    await db.commit()
    await db.refresh(area)
    return AreaRead.model_validate(area)


@router.put("/{area_id}", response_model=AreaRead, summary="Update an area (admin)")
async def update_area(
    area_id: int,
    payload: AreaUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> AreaRead:
    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(area, field, value)

    await db.commit()
    await db.refresh(area)
    return AreaRead.model_validate(area)


@router.patch(
    "/{area_id}/toggle-active",
    response_model=AreaRead,
    summary="Toggle the `is_active` flag (admin)",
)
async def toggle_active(
    area_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> AreaRead:
    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")

    area.is_active = not area.is_active
    await db.commit()
    await db.refresh(area)
    return AreaRead.model_validate(area)


@router.delete(
    "/{area_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an area (admin)",
)
async def delete_area(
    area_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
) -> None:
    area = await db.get(Area, area_id)
    if area is None:
        raise not_found("Area")
    await db.delete(area)
    await db.commit()
