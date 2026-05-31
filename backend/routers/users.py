"""
routers/users.py
----------------
Kullanıcı kayıt ve bildirim tercihleri endpoint'leri.

KVKK Notu: Kullanıcı sadece FCM token ile tanınır, kişisel bilgi (isim,
mail, telefon) toplanmaz. Token bir cihaz tanımlayıcısıdır ve uygulama
silindiğinde otomatik olarak geçersiz hale gelir.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import (
    Area,
    NotificationPreference,
    PreferenceItem,
    PreferencesUpdateRequest,
    User,
    UserOut,
    UserRegisterRequest,
)

router = APIRouter(prefix="/api/users", tags=["users"])


def _upsert_preferences(
    db: Session, user: User, items: list[PreferenceItem]
) -> list[PreferenceItem]:
    """Kullanıcının tercihlerini günceller/ekler."""
    valid_area_ids = {a.id for a in db.query(Area.id).all()}
    # önce mevcutları sil — basit ve atomik yaklaşım
    db.query(NotificationPreference).filter(
        NotificationPreference.user_id == user.id
    ).delete(synchronize_session=False)

    out: list[PreferenceItem] = []
    for item in items:
        if item.area_id not in valid_area_ids:
            raise HTTPException(
                status_code=400, detail=f"Geçersiz area_id: {item.area_id}"
            )
        pref = NotificationPreference(
            user_id=user.id,
            area_id=item.area_id,
            threshold_pct=item.threshold_pct,
            notify_when=item.notify_when,
            enabled=1 if item.enabled else 0,
        )
        db.add(pref)
        out.append(item)
    return out


@router.post("/register", response_model=UserOut, summary="Kullanıcı kayıt / upsert")
def register_user(
    payload: UserRegisterRequest, db: Session = Depends(get_db)
) -> UserOut:
    """
    FCM token ile kullanıcı kaydı oluşturur veya günceller (upsert).
    Tercihler verilirse atomik olarak güncellenir.
    """
    user = db.query(User).filter(User.fcm_token == payload.fcm_token).first()
    if not user:
        user = User(fcm_token=payload.fcm_token)
        db.add(user)
        db.flush()  # id üretmek için

    prefs = _upsert_preferences(db, user, payload.preferences)
    db.commit()
    db.refresh(user)

    return UserOut(id=user.id, fcm_token=user.fcm_token, preferences=prefs)


@router.post(
    "/preferences",
    response_model=UserOut,
    summary="Bildirim tercihlerini güncelle",
)
def update_preferences(
    payload: PreferencesUpdateRequest, db: Session = Depends(get_db)
) -> UserOut:
    """Kullanıcının bildirim tercihlerini günceller."""
    user = db.query(User).filter(User.fcm_token == payload.fcm_token).first()
    if not user:
        # Otomatik upsert davranışı: kullanıcı yoksa oluştur
        user = User(fcm_token=payload.fcm_token)
        db.add(user)
        db.flush()

    prefs = _upsert_preferences(db, user, payload.preferences)
    db.commit()
    db.refresh(user)

    return UserOut(id=user.id, fcm_token=user.fcm_token, preferences=prefs)


@router.get(
    "/{fcm_token}/preferences",
    response_model=list[PreferenceItem],
    summary="Kullanıcının mevcut tercihleri",
)
def get_preferences(fcm_token: str, db: Session = Depends(get_db)) -> list[PreferenceItem]:
    """Kullanıcının mevcut bildirim tercihlerini döndürür."""
    user = db.query(User).filter(User.fcm_token == fcm_token).first()
    if not user:
        return []
    return [
        PreferenceItem(
            area_id=p.area_id,
            threshold_pct=p.threshold_pct,
            notify_when=p.notify_when,
            enabled=bool(p.enabled),
        )
        for p in user.preferences
    ]
