from typing import List, Optional, Any
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from database_firestore import db, save_occupancy_to_firestore

router = APIRouter(prefix="/occupancy", tags=["occupancy"])

class IngestRequest(BaseModel):
    area_id: str
    device_count: int

class LiveAreaData(BaseModel):
    area_id: str
    area_name: str
    short_name: str
    building: str
    icon: str
    capacity: int
    device_count: int
    occupancy_pct: float
    status: str
    color: str
    last_updated: Any

    class Config:
        from_attributes = True

def get_occupancy_status(pct: float) -> str:
    if pct < 30: return "Boş"
    elif pct < 60: return "Orta"
    elif pct < 85: return "Dolu"
    else: return "Çok Dolu"

def get_occupancy_color(pct: float) -> str:
    if pct < 30: return "green"
    elif pct < 60: return "yellow"
    elif pct < 85: return "orange"
    else: return "red"

@router.get("/live", response_model=List[LiveAreaData])
def get_live_occupancy():
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    areas_ref = db.collection("areas")
    docs = areas_ref.stream()
    results = []
    for doc in docs:
        data = doc.to_dict()
        if not data.get("is_active"): continue
        pct = data.get("live_occupancy_pct", 0.0)
        results.append(LiveAreaData(
            area_id=doc.id,
            area_name=data.get("name", ""),
            short_name=data.get("short_name", ""),
            building=data.get("building", ""),
            icon=data.get("icon", ""),
            capacity=data.get("capacity", 0),
            device_count=data.get("live_device_count", 0),
            occupancy_pct=pct,
            status=get_occupancy_status(pct),
            color=get_occupancy_color(pct),
            last_updated=data.get("last_updated") or datetime.now()
        ))
    return results

# Specific endpoints for different areas as requested
@router.get("/library", response_model=LiveAreaData)
def get_library_occupancy():
    """Kütüphane doluluk oranını ölçen özel endpoint."""
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    doc = db.collection("areas").document("library").get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Library area not found")
    data = doc.to_dict()
    pct = data.get("live_occupancy_pct", 0.0)
    return LiveAreaData(
        area_id=doc.id,
        area_name=data.get("name", "Kütüphane"),
        short_name=data.get("short_name", "Kütüphane"),
        building=data.get("building", ""),
        icon=data.get("icon", "📚"),
        capacity=data.get("capacity", 300),
        device_count=data.get("live_device_count", 0),
        occupancy_pct=pct,
        status=get_occupancy_status(pct),
        color=get_occupancy_color(pct),
        last_updated=data.get("last_updated") or datetime.now()
    )

@router.get("/cafeteria", response_model=LiveAreaData)
def get_cafeteria_occupancy():
    """Yemekhane doluluk oranını ölçen özel endpoint."""
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    doc = db.collection("areas").document("cafeteria").get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Cafeteria area not found")
    data = doc.to_dict()
    pct = data.get("live_occupancy_pct", 0.0)
    return LiveAreaData(
        area_id=doc.id,
        area_name=data.get("name", "Yemekhane"),
        short_name=data.get("short_name", "Yemekhane"),
        building=data.get("building", ""),
        icon=data.get("icon", "🍽️"),
        capacity=data.get("capacity", 500),
        device_count=data.get("live_device_count", 0),
        occupancy_pct=pct,
        status=get_occupancy_status(pct),
        color=get_occupancy_color(pct),
        last_updated=data.get("last_updated") or datetime.now()
    )

@router.post("/ingest")
def ingest(payload: IngestRequest):
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    area_doc = db.collection("areas").document(payload.area_id).get()
    if not area_doc.exists:
        raise HTTPException(status_code=404, detail="Alan bulunamadı")
        
    capacity = area_doc.to_dict().get("capacity", 1)
    record = save_occupancy_to_firestore(payload.area_id, payload.device_count, capacity)
    return {"status": "ok", "occupancy_pct": record["occupancy_pct"]}

@router.post("/ingest/bulk")
def ingest_bulk(payloads: List[IngestRequest]):
    if not db:
        raise HTTPException(status_code=500, detail="Firestore is not connected")
    results = []
    for payload in payloads:
        area_doc = db.collection("areas").document(payload.area_id).get()
        if not area_doc.exists:
            results.append({"area_id": payload.area_id, "status": "error", "detail": "Not found"})
            continue
        capacity = area_doc.to_dict().get("capacity", 1)
        record = save_occupancy_to_firestore(payload.area_id, payload.device_count, capacity)
        results.append({"area_id": payload.area_id, "status": "ok", "occupancy_pct": record["occupancy_pct"]})
    return results
