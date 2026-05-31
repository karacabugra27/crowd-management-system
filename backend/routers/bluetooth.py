"""
routers/bluetooth.py
--------------------
Emre'nin mobil Bluetooth dinleyicisinden gelen cihaz sayısını alır,
InfluxDB'ye yazar ve WebSocket istemcilerine anında yayınlar.

POST /api/bluetooth/report
{
  "area_id": "kutuphane",
  "device_count": 47,
  "listener_id": "emre-phone-01"   # isteğe bağlı, loglama için
}
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from influxdb_client import Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from models import Area
from services.influx_service import get_influx_service, occupancy_status

logger = logging.getLogger(__name__)
_settings = get_settings()

router = APIRouter(prefix="/api/bluetooth", tags=["bluetooth"])


# ---------- Pydantic ----------
class BluetoothReport(BaseModel):
    area_id: str = Field(..., description="Kampüs alan ID'si (örn: 'kutuphane')")
    area_name: str | None = Field(default=None, description="Mobil alandan gelen özel isim")
    device_count: int = Field(..., ge=0, description="Algılanan Bluetooth cihaz sayısı")
    listener_id: str = Field(default="unknown", description="Dinleyici cihaz kimliği")
    latitude: float | None = Field(default=None, description="Telefondan gelen gerçek GPS enlemi")
    longitude: float | None = Field(default=None, description="Telefondan gelen gerçek GPS boylamı")


class BluetoothReportResponse(BaseModel):
    success: bool
    area_id: str
    device_count: int
    occupancy_pct: float
    status: str
    message: str


# ---------- Endpoint ----------
@router.post("/report", response_model=BluetoothReportResponse)
def bluetooth_report(
    payload: BluetoothReport,
    db: Session = Depends(get_db),
) -> BluetoothReportResponse:
    """
    Bluetooth dinleyiciden gelen cihaz sayısını alır ve InfluxDB'ye kaydeder.
    Auth gerektirmez — dinleyici cihaz basit POST atar.
    """
    # 1. Alan kontrolü
    area = db.query(Area).filter(Area.id == payload.area_id).first()
    if not area:
        import random
        # Kütüphane etrafında rastgele bir konuma dağıt (üst üste binmemesi için) - YEDEK
        lat_offset = random.uniform(-0.0015, 0.0015)
        lng_offset = random.uniform(-0.0015, 0.0015)
        
        lat = payload.latitude if payload.latitude is not None else (38.3334 + lat_offset)
        lng = payload.longitude if payload.longitude is not None else (38.4397 + lng_offset)
        
        custom_name = payload.area_name if payload.area_name else f"Mobil Alan ({payload.area_id[-4:]})"
        
        logger.info("Yeni alan oluşturuluyor: %s (%.4f, %.4f) - İsim: %s", payload.area_id, lat, lng, custom_name)
        area = Area(
            id=payload.area_id,
            name=custom_name,
            capacity=100,
            latitude=lat,
            longitude=lng,
            floor=0,
        )
        db.add(area)
        db.commit()
        db.refresh(area)
    else:
        # Eğer mobil alan (loc_...) ise ve telefondan yeni konum gelmişse, koordinatı güncelle!
        if payload.area_id.startswith("loc_") and payload.latitude and payload.longitude:
            # Çok ufak değişiklikleri sürekli DB'ye yazmamak için basit kontrol
            if abs(area.latitude - payload.latitude) > 0.00001 or abs(area.longitude - payload.longitude) > 0.00001:
                area.latitude = payload.latitude
                area.longitude = payload.longitude
                db.commit()
                db.refresh(area)

    # 2. Doluluk hesapla
    capacity = max(area.capacity, 1)
    device_count = min(payload.device_count, capacity + 10)  # mantıklı üst sınır
    pct = round((device_count / capacity) * 100, 2)
    s = occupancy_status(pct)

    logger.info(
        "BT rapor alındı | area=%s listener=%s cihaz=%d kapasite=%d pct=%.1f%% durum=%s",
        area.id,
        payload.listener_id,
        device_count,
        capacity,
        pct,
        s,
    )

    # 3. InfluxDB'ye yaz
    try:
        influx = get_influx_service()
        write_api = influx._client.write_api(write_options=SYNCHRONOUS)
        point = (
            Point("occupancy")
            .tag("area_id", area.id)
            .tag("area_name", area.name)
            .tag("source", "bluetooth")
            .tag("listener_id", payload.listener_id)
            .field("device_count", device_count)
            .field("occupancy_pct", pct)
            .field("capacity", capacity)
            .time(datetime.now(timezone.utc), WritePrecision.S)
        )
        write_api.write(bucket=_settings.influxdb_bucket, org=_settings.influxdb_org, record=point)
        logger.info("InfluxDB yazma başarılı | area=%s", area.id)
    except Exception:
        logger.exception("InfluxDB yazma hatası | area=%s", area.id)
        # InfluxDB hatası olsa bile 200 dön — veri alındı, sadece yazılamadı
        return BluetoothReportResponse(
            success=False,
            area_id=area.id,
            device_count=device_count,
            occupancy_pct=pct,
            status=s,
            message="Veri alındı ancak veritabanına kaydedilemedi",
        )

    return BluetoothReportResponse(
        success=True,
        area_id=area.id,
        device_count=device_count,
        occupancy_pct=pct,
        status=s,
        message="Veri başarıyla kaydedildi",
    )


@router.get("/areas", summary="Geçerli alan listesi")
def get_areas(db: Session = Depends(get_db)) -> list[dict]:
    """Dinleyici uygulamanın kullanabileceği alan listesi."""
    areas = db.query(Area).order_by(Area.name).all()
    return [
        {
            "id": a.id,
            "name": a.name,
            "capacity": a.capacity,
            "latitude": a.latitude,
            "longitude": a.longitude,
        }
        for a in areas
    ]
