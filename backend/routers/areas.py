"""
routers/areas.py
----------------
GET /api/areas — tüm kampüs alanlarının listesi.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models import Area, AreaOut

router = APIRouter(prefix="/api/areas", tags=["areas"])


@router.get("", response_model=list[AreaOut], summary="Tüm alanları listele")
def list_areas(db: Session = Depends(get_db)) -> list[AreaOut]:
    """Veritabanındaki tüm kampüs alanlarını döndürür."""
    return [AreaOut.model_validate(a) for a in db.query(Area).order_by(Area.name).all()]


@router.get("/{area_id}", response_model=AreaOut, summary="Alan detayı")
def get_area(area_id: str, db: Session = Depends(get_db)) -> AreaOut:
    """Tek bir alanın detayını döndürür."""
    from fastapi import HTTPException

    area = db.query(Area).filter(Area.id == area_id).first()
    if not area:
        raise HTTPException(status_code=404, detail="Alan bulunamadı")
    return AreaOut.model_validate(area)
