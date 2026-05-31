"""
celery_tasks.py
---------------
Celery worker — periyodik doluluk kontrolü ve bildirim tetikleme.

Beat schedule:
  - check_occupancy_and_notify: her 60 saniyede bir
"""

from __future__ import annotations

import logging
from datetime import timedelta

from celery import Celery
from celery.schedules import schedule

from config import get_settings
from database import session_scope
from models import Area, NotificationPreference, User
from services.influx_service import get_influx_service, occupancy_status
from services.notification_service import is_on_cooldown, send_push

logger = logging.getLogger(__name__)
_settings = get_settings()

celery_app = Celery(
    "campus",
    broker=_settings.celery_broker_url,
    backend=_settings.celery_result_backend,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Europe/Istanbul",
    enable_utc=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    beat_schedule={
        "check-occupancy-every-minute": {
            "task": "services.celery_tasks.check_occupancy_and_notify",
            "schedule": schedule(
                run_every=timedelta(seconds=_settings.notification_check_interval_seconds)
            ),
        }
    },
)


@celery_app.task(name="services.celery_tasks.check_occupancy_and_notify")
def check_occupancy_and_notify() -> dict:
    """
    Tüm alanların anlık doluluğunu kontrol eder ve eşiği aşan kullanıcılara
    FCM bildirimi gönderir.

    Returns:
        Çalışma özeti: {checked: n, notified: m}
    """
    influx = get_influx_service()
    latest = influx.get_latest_for_all()
    notified = 0

    with session_scope() as db:
        areas = {a.id: a for a in db.query(Area).all()}
        prefs = (
            db.query(NotificationPreference, User)
            .join(User, NotificationPreference.user_id == User.id)
            .filter(NotificationPreference.enabled == 1)
            .all()
        )

        for pref, user in prefs:
            data = latest.get(pref.area_id)
            area = areas.get(pref.area_id)
            if not data or not area:
                continue

            pct = float(data["occupancy_pct"])
            threshold = pref.threshold_pct
            direction = pref.notify_when

            should_notify = (
                (direction == "above" and pct >= threshold)
                or (direction == "below" and pct <= threshold)
            )
            if not should_notify:
                continue

            if is_on_cooldown(user.fcm_token, pref.area_id):
                continue

            ok = send_push(
                fcm_token=user.fcm_token,
                area_id=pref.area_id,
                area_name=area.name,
                occupancy_pct=pct,
                direction=direction,
                user_id=user.id,
            )
            if ok:
                notified += 1

    summary = {"checked": len(latest), "notified": notified}
    logger.info("check_occupancy_and_notify: %s", summary)
    return summary


@celery_app.task(name="services.celery_tasks.health_check")
def health_check() -> str:
    """Worker'ın çalıştığını doğrulamak için basit task."""
    return "ok"
