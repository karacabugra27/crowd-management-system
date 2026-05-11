"""
Wi-Fi AP Polling Collector

Reads simulated (or real SNMP) data from access points and pushes it
to the FastAPI backend every POLL_INTERVAL_SECONDS.

Usage:
    python collector.py

Environment variables:
    API_BASE_URL         FastAPI backend URL (default: http://localhost:8000)
    POLL_INTERVAL_SECONDS  How often to poll (default: 60)
    USE_MOCK             Set to 'false' to use real SNMP (default: true)
"""
import os
import time
import logging
import requests
from datetime import datetime

from mock_generator import generate_readings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [COLLECTOR] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL_SECONDS", "60"))
USE_MOCK = os.getenv("USE_MOCK", "true").lower() == "true"

INGEST_URL = f"{API_BASE_URL}/occupancy/ingest/bulk"


def wait_for_backend(max_retries: int = 30, delay: int = 3):
    """Wait until the backend is ready."""
    for attempt in range(max_retries):
        try:
            r = requests.get(f"{API_BASE_URL}/health", timeout=5)
            if r.status_code == 200:
                logger.info("✅ Backend hazır.")
                return
        except Exception:
            pass
        logger.info(f"⏳ Backend bekleniyor... ({attempt + 1}/{max_retries})")
        time.sleep(delay)
    raise RuntimeError("Backend başlatılamadı. Collector durduruluyor.")


def collect_and_send():
    """One poll cycle: collect readings and POST to backend."""
    if USE_MOCK:
        readings = generate_readings()
    else:
        # TODO: real SNMP/SSH collection
        # from snmp_collector import collect_snmp
        # readings = collect_snmp()
        readings = generate_readings()

    payload = [
        {"area_id": r["area_id"], "device_count": r["device_count"]}
        for r in readings
    ]

    try:
        response = requests.post(INGEST_URL, json=payload, timeout=10)
        response.raise_for_status()
        results = response.json()

        success = sum(1 for r in results if r.get("status") == "ok")
        logger.info(
            f"📡 {success}/{len(readings)} alan güncellendi @ "
            f"{datetime.now().strftime('%H:%M:%S')}"
        )

        # Log each area's reading
        for r in readings:
            status_icon = "🟢" if r["simulated_pct"] < 30 else ("🟡" if r["simulated_pct"] < 60 else ("🟠" if r["simulated_pct"] < 85 else "🔴"))
            logger.info(
                f"  {status_icon} {r['area_name']:<35} "
                f"{r['device_count']:>4} cihaz  %{r['simulated_pct']:5.1f}"
            )

    except requests.RequestException as e:
        logger.error(f"❌ Backend isteği başarısız: {e}")


def main():
    logger.info("=" * 60)
    logger.info("🏫 Kampüs Wi-Fi Polling Servisi başlatılıyor...")
    logger.info(f"   Backend  : {API_BASE_URL}")
    logger.info(f"   Aralık   : {POLL_INTERVAL}s")
    logger.info(f"   Mod      : {'Mock (Simülasyon)' if USE_MOCK else 'Gerçek SNMP'}")
    logger.info("=" * 60)

    wait_for_backend()

    # Initial poll immediately
    collect_and_send()

    while True:
        time.sleep(POLL_INTERVAL)
        collect_and_send()


if __name__ == "__main__":
    main()
