"""Notifications router — subscription management."""
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db, NotificationSubscription, Area

router = APIRouter(prefix="/notifications", tags=["notifications"])


class SubscribeRequest(BaseModel):
    fcm_token: str
    area_id: int
    threshold_pct: float = 80.0
    direction: str = "above"  # 'above' or 'below'


class SubscriptionResponse(BaseModel):
    id: int
    fcm_token: str
    area_id: int
    area_name: str
    threshold_pct: float
    direction: str

    class Config:
        from_attributes = True


@router.post("/subscribe", response_model=SubscriptionResponse)
def subscribe(payload: SubscribeRequest, db: Session = Depends(get_db)):
    """Subscribe a device to occupancy threshold notifications for an area."""
    if payload.direction not in ("above", "below"):
        raise HTTPException(status_code=400, detail="direction 'above' veya 'below' olmalı")

    area = db.query(Area).filter(Area.id == payload.area_id).first()
    if not area:
        raise HTTPException(status_code=404, detail="Alan bulunamadı")

    # Upsert: update existing subscription for same token+area
    existing = (
        db.query(NotificationSubscription)
        .filter(
            NotificationSubscription.fcm_token == payload.fcm_token,
            NotificationSubscription.area_id == payload.area_id,
        )
        .first()
    )

    if existing:
        existing.threshold_pct = payload.threshold_pct
        existing.direction = payload.direction
        db.commit()
        db.refresh(existing)
        sub = existing
    else:
        sub = NotificationSubscription(
            fcm_token=payload.fcm_token,
            area_id=payload.area_id,
            threshold_pct=payload.threshold_pct,
            direction=payload.direction,
        )
        db.add(sub)
        db.commit()
        db.refresh(sub)

    return SubscriptionResponse(
        id=sub.id,
        fcm_token=sub.fcm_token,
        area_id=sub.area_id,
        area_name=area.name,
        threshold_pct=sub.threshold_pct,
        direction=sub.direction,
    )


@router.delete("/subscribe/{subscription_id}")
def unsubscribe(subscription_id: int, db: Session = Depends(get_db)):
    """Cancel a notification subscription."""
    sub = db.query(NotificationSubscription).filter(
        NotificationSubscription.id == subscription_id
    ).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Abonelik bulunamadı")
    db.delete(sub)
    db.commit()
    return {"status": "ok", "message": "Abonelik iptal edildi"}


@router.get("/subscriptions/{fcm_token}", response_model=List[SubscriptionResponse])
def list_subscriptions(fcm_token: str, db: Session = Depends(get_db)):
    """List all subscriptions for a given FCM token."""
    subs = (
        db.query(NotificationSubscription)
        .filter(NotificationSubscription.fcm_token == fcm_token)
        .all()
    )
    result = []
    for sub in subs:
        area = db.query(Area).filter(Area.id == sub.area_id).first()
        result.append(
            SubscriptionResponse(
                id=sub.id,
                fcm_token=sub.fcm_token,
                area_id=sub.area_id,
                area_name=area.name if area else "Bilinmiyor",
                threshold_pct=sub.threshold_pct,
                direction=sub.direction,
            )
        )
    return result
