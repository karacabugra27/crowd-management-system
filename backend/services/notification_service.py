"""
notification_service.py
-----------------------
Firebase Cloud Messaging entegrasyonu ve cooldown yönetimi.

- Firebase Admin SDK ile token bazlı push gönderimi
- Redis ile per-(user, area) 15 dk cooldown
- Bildirim kaydı Postgres'e yazılır (NotificationLog)
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import redis
from firebase_admin import credentials, initialize_app, messaging
from firebase_admin.exceptions import FirebaseError

from config import get_settings
from database import session_scope
from models import NotificationLog

logger = logging.getLogger(__name__)
_settings = get_settings()

_firebase_app = None
_redis_client: Optional[redis.Redis] = None


def _init_firebase() -> None:
    """Firebase Admin SDK'yı initialize eder (idempotent)."""
    global _firebase_app
    if _firebase_app is not None:
        return
    creds_path = _settings.firebase_credentials_path
    if not os.path.exists(creds_path):
        logger.warning(
            "Firebase credentials bulunamadı (%s) — FCM devre dışı.", creds_path
        )
        return
    try:
        cred = credentials.Certificate(creds_path)
        _firebase_app = initialize_app(cred)
        logger.info("Firebase Admin SDK initialize edildi")
    except Exception:  # noqa: BLE001
        logger.exception("Firebase initialize hatası")


def _get_redis() -> redis.Redis:
    """Redis bağlantısını döndürür (lazy)."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(_settings.redis_url, decode_responses=True)
    return _redis_client


def _cooldown_key(fcm_token: str, area_id: str) -> str:
    """Cooldown için Redis anahtarı."""
    # Token'ın tamamı yerine kısaltma kullan (log güvenliği)
    short = fcm_token[-12:] if len(fcm_token) > 12 else fcm_token
    return f"notif:cooldown:{short}:{area_id}"


def is_on_cooldown(fcm_token: str, area_id: str) -> bool:
    """Bu (user, area) için aktif cooldown var mı?"""
    try:
        return bool(_get_redis().exists(_cooldown_key(fcm_token, area_id)))
    except Exception:  # noqa: BLE001
        logger.exception("Cooldown kontrolünde Redis hatası")
        return False


def set_cooldown(fcm_token: str, area_id: str) -> None:
    """Cooldown süresi kadar Redis'e flag yazar."""
    try:
        ttl = max(60, _settings.notification_cooldown_minutes * 60)
        _get_redis().setex(_cooldown_key(fcm_token, area_id), ttl, "1")
    except Exception:  # noqa: BLE001
        logger.exception("Cooldown set hatası")


def _build_message(area_name: str, occupancy_pct: float, direction: str) -> str:
    """Bildirim metni üretir."""
    if direction == "above":
        return f"📍 {area_name} doluluk oranı %{occupancy_pct:.0f} seviyesine ulaştı"
    return f"✅ {area_name} boşalıyor — şu anda %{occupancy_pct:.0f} dolu"


def send_push(
    fcm_token: str,
    area_id: str,
    area_name: str,
    occupancy_pct: float,
    direction: str = "above",
    user_id: int | None = None,
) -> bool:
    """
    FCM üzerinden tek bir kullanıcıya push bildirimi gönderir.

    Returns:
        Başarılıysa True
    """
    _init_firebase()
    if _firebase_app is None:
        logger.debug("FCM devre dışı — bildirim atlandı (area=%s)", area_id)
        return False

    if is_on_cooldown(fcm_token, area_id):
        logger.info(
            "Cooldown aktif: token=...%s area=%s",
            fcm_token[-8:],
            area_id,
        )
        return False

    message_text = _build_message(area_name, occupancy_pct, direction)
    title = "Kampüs Doluluk Uyarısı"

    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=message_text),
        data={
            "area_id": area_id,
            "area_name": area_name,
            "occupancy_pct": str(round(occupancy_pct, 2)),
            "direction": direction,
            "type": "occupancy_alert",
        },
        token=fcm_token,
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", content_available=True)
            ),
        ),
    )
    try:
        response = messaging.send(msg)
        logger.info("FCM gönderildi: %s (area=%s)", response, area_id)
        set_cooldown(fcm_token, area_id)

        # NotificationLog kaydı
        try:
            with session_scope() as db:
                db.add(
                    NotificationLog(
                        user_id=user_id,
                        area_id=area_id,
                        occupancy_pct=occupancy_pct,
                        message=message_text,
                        sent_at=datetime.now(timezone.utc),
                    )
                )
        except Exception:  # noqa: BLE001
            logger.exception("NotificationLog kaydı başarısız")

        return True
    except FirebaseError as e:
        logger.warning("FCM gönderim hatası (area=%s): %s", area_id, e)
        return False
    except Exception:  # noqa: BLE001
        logger.exception("FCM beklenmedik hata")
        return False
