from typing import List, Any
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database_firestore import db

router = APIRouter(prefix="/areas", tags=["areas"])

class AreaResponse(BaseModel):
    id: str
    name: str
    short_name: str
    capacity: int
    floor: str
    building: str
    icon: str
    is_active: bool

    class Config:
        from_attributes = True

@router.get("/", response_model=List[AreaResponse])
def list_areas():
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    docs = db.collection("areas").stream()
    results = []
    for doc in docs:
        data = doc.to_dict()
        if data.get("is_active"):
            results.append(AreaResponse(
                id=doc.id,
                name=data.get("name", ""),
                short_name=data.get("short_name", ""),
                capacity=data.get("capacity", 0),
                floor=data.get("floor", ""),
                building=data.get("building", ""),
                icon=data.get("icon", ""),
                is_active=data.get("is_active", True)
            ))
    return results

@router.get("/{area_id}", response_model=AreaResponse)
def get_area(area_id: str):
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    doc = db.collection("areas").document(area_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Alan bulunamadı")
    data = doc.to_dict()
    return AreaResponse(
        id=doc.id,
        name=data.get("name", ""),
        short_name=data.get("short_name", ""),
        capacity=data.get("capacity", 0),
        floor=data.get("floor", ""),
        building=data.get("building", ""),
        icon=data.get("icon", ""),
        is_active=data.get("is_active", True)
    )
