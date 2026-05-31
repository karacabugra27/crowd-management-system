"""Occupancy calculation and threshold-based notification triggering."""
from datetime import datetime
from sqlalchemy.orm import Session
from database import Area, OccupancyRecord, NotificationSubscription
from services.fcm_service import send_push_notification


def calculate_occupancy(device_count: int, capacity: int) -> float:
    """Calculate occupancy percentage capped at 100."""
    if capacity <= 0:
        return 0.0
    return min(round((device_count / capacity) * 100, 1), 100.0)


def get_occupancy_status(pct: float) -> str:
    """Return a human-readable status string."""
    if pct < 30:
        return "Boş"
    elif pct < 60:
        return "Orta"
    elif pct < 85:
        return "Dolu"
    else:
        return "Çok Dolu"


def get_occupancy_color(pct: float) -> str:
    """Return a CSS colour class based on occupancy."""
    if pct < 30:
        return "green"
    elif pct < 60:
        return "yellow"
    elif pct < 85:
        return "orange"
    else:
        return "red"


def ingest_occupancy(db: Session, area_id: int, device_count: int) -> OccupancyRecord:
    """Store a new occupancy record and trigger notifications if needed."""
    area: Area = db.query(Area).filter(Area.id == area_id).first()
    if not area:
        raise ValueError(f"Alan bulunamadı: {area_id}")

    pct = calculate_occupancy(device_count, area.capacity)

    record = OccupancyRecord(
        area_id=area_id,
        timestamp=datetime.utcnow(),
        device_count=device_count,
        occupancy_pct=pct,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    # Check thresholds and notify subscribers
    _check_and_notify(db, area, pct)

    return record


def _check_and_notify(db: Session, area: Area, current_pct: float):
    """Check all subscriptions for this area and fire FCM if threshold crossed."""
    subscriptions = (
        db.query(NotificationSubscription)
        .filter(NotificationSubscription.area_id == area.id)
        .all()
    )

    for sub in subscriptions:
        should_notify = False
        message = ""

        if sub.direction == "above" and current_pct >= sub.threshold_pct:
            should_notify = True
            message = (
                f"⚠️ {area.name} şu an %{int(current_pct)} dolu! "
                f"Eşik değeriniz: %{int(sub.threshold_pct)}"
            )
        elif sub.direction == "below" and current_pct <= sub.threshold_pct:
            should_notify = True
            message = (
                f"✅ {area.name} şu an %{int(current_pct)} dolu. "
                f"Müsait yer var!"
            )

        if should_notify:
            send_push_notification(
                token=sub.fcm_token,
                title="Kampüs Doluluk Uyarısı",
                body=message,
                data={"area_id": str(area.id), "occupancy_pct": str(current_pct)},
            )
