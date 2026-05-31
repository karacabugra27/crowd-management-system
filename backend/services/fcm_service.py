"""Firebase Cloud Messaging service.

When FCM_SERVER_KEY is set in environment variables, real push notifications
are sent via the FCM HTTP v1 API. Otherwise, notifications are logged to
console (mock mode) so the system works without a Firebase project.
"""
import os
import json
import logging

logger = logging.getLogger(__name__)

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")
FCM_URL = "https://fcm.googleapis.com/fcm/send"


def send_push_notification(token: str, title: str, body: str, data: dict = None) -> bool:
    """Send a push notification via FCM or log in mock mode."""
    payload = {
        "to": token,
        "notification": {
            "title": title,
            "body": body,
            "sound": "default",
        },
        "data": data or {},
    }

    if not FCM_SERVER_KEY:
        # Mock mode — log to console for demo purposes
        logger.info(
            f"[FCM MOCK] 📲 Bildirim gönderildi:\n"
            f"  Token : {token[:20]}...\n"
            f"  Başlık: {title}\n"
            f"  Mesaj : {body}\n"
            f"  Data  : {json.dumps(data)}"
        )
        return True

    try:
        import requests

        response = requests.post(
            FCM_URL,
            headers={
                "Authorization": f"key={FCM_SERVER_KEY}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=10,
        )
        response.raise_for_status()
        logger.info(f"[FCM] Bildirim gönderildi → {response.json()}")
        return True
    except Exception as e:
        logger.error(f"[FCM] Bildirim gönderilemedi: {e}")
        return False
