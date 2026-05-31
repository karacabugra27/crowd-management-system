"""
main.py
-------
Veri Toplama Servisi giriş noktası.

Her N saniyede bir (varsayılan 60):
  1. Tüm tanımlı kampüs alanları için Mock AP üzerinden cihaz MAC'lerini
     toplar (gerçek AP entegrasyonu için bu kısım değiştirilebilir).
  2. MAC adreslerini SHA-256 ile anonimleştirir, ham MAC asla loglanmaz.
  3. Doluluk oranını alan kapasitesine göre hesaplar.
  4. InfluxDB'ye `occupancy` measurement'i altında yazar.

Hata yönetimi:
  - InfluxDB erişilemezse exponential backoff ile retry yapar, servis çökmez.
  - Bir alan için hata oluşursa diğer alanların yazımı engellenmez.
"""

from __future__ import annotations

import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone

from dotenv import load_dotenv
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

from anonymizer import hash_macs
from mock_ap import Area, get_areas, simulate_devices

# ----------------------------------------------------------------------
# Yapılandırma
# ----------------------------------------------------------------------
load_dotenv()

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
INTERVAL = int(os.getenv("COLLECTOR_INTERVAL_SECONDS", "60"))
USE_MOCK = os.getenv("COLLECTOR_USE_MOCK", "true").lower() == "true"

INFLUX_URL = os.getenv("INFLUXDB_URL", "http://influxdb:8086")
INFLUX_TOKEN = os.getenv("INFLUXDB_TOKEN", "")
INFLUX_ORG = os.getenv("INFLUXDB_ORG", "campus")
INFLUX_BUCKET = os.getenv("INFLUXDB_BUCKET", "occupancy")

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("collector")

# Graceful shutdown bayrağı
_shutdown_requested = False


def _handle_signal(signum, _frame):
    """SIGTERM / SIGINT alındığında döngüyü temiz kapatır."""
    global _shutdown_requested
    logger.info("Sinyal alındı (%s), kapanış başlatılıyor...", signum)
    _shutdown_requested = True


signal.signal(signal.SIGTERM, _handle_signal)
signal.signal(signal.SIGINT, _handle_signal)


# ----------------------------------------------------------------------
# InfluxDB istemcisi (lazy init + retry)
# ----------------------------------------------------------------------
def build_influx_client() -> InfluxDBClient:
    """InfluxDB istemcisini oluşturur."""
    return InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)


def collect_for_area(area: Area) -> tuple[int, float]:
    """
    Bir alan için cihaz sayısı ve doluluk yüzdesini hesaplar.

    Returns:
        (anonim_cihaz_sayısı, doluluk_yüzdesi)
    """
    if USE_MOCK:
        raw_macs = simulate_devices(area)
    else:
        # Gerçek AP entegrasyonu burada yapılacak (örn. SNMP, Cisco DNA, vb.)
        raw_macs = simulate_devices(area)

    # KVKK: ham MAC adresini hiçbir yere yazma, sadece hash setinin
    # büyüklüğüne bak. raw_macs bu noktadan sonra scope dışı kalmalı.
    anonymized = hash_macs(raw_macs)
    del raw_macs  # bilinçli olarak referansı kaldırıyoruz

    device_count = len(anonymized)
    occupancy_pct = round(min(100.0, (device_count / area.capacity) * 100.0), 2)
    return device_count, occupancy_pct


def write_point(write_api, area: Area, device_count: int, occupancy_pct: float) -> None:
    """Tek bir doluluk ölçümünü InfluxDB'ye yazar."""
    point = (
        Point("occupancy")
        .tag("area_id", area.id)
        .tag("area_name", area.name)
        .field("device_count", int(device_count))
        .field("occupancy_pct", float(occupancy_pct))
        .field("capacity", int(area.capacity))
        .time(datetime.now(timezone.utc), WritePrecision.NS)
    )
    write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=point)


def run_once(client: InfluxDBClient) -> None:
    """Tüm alanlar için tek bir toplama turu çalıştırır."""
    write_api = client.write_api(write_options=SYNCHRONOUS)
    for area in get_areas():
        try:
            device_count, occupancy_pct = collect_for_area(area)
            write_point(write_api, area, device_count, occupancy_pct)
            logger.info(
                "Yazıldı: %s — %d cihaz, %.1f%% doluluk",
                area.id,
                device_count,
                occupancy_pct,
            )
        except Exception:  # noqa: BLE001
            logger.exception("Alan işlenirken hata: %s", area.id)


def main() -> int:
    """Servisin ana döngüsü."""
    logger.info("Collector başlıyor (interval=%ss, mock=%s)", INTERVAL, USE_MOCK)

    if not INFLUX_TOKEN:
        logger.error("INFLUXDB_TOKEN tanımlı değil, çıkılıyor.")
        return 1

    backoff = 1.0
    client: InfluxDBClient | None = None

    while not _shutdown_requested:
        try:
            if client is None:
                client = build_influx_client()
                # Bağlantıyı doğrula
                client.ping()
                logger.info("InfluxDB bağlantısı OK")
                backoff = 1.0

            run_once(client)
            # interval kadar bekle ama shutdown'a duyarlı kal
            for _ in range(INTERVAL):
                if _shutdown_requested:
                    break
                time.sleep(1)
        except Exception:  # noqa: BLE001
            logger.exception(
                "Toplama döngüsünde hata, %s saniye sonra tekrar denenecek", backoff
            )
            if client is not None:
                try:
                    client.close()
                except Exception:  # noqa: BLE001
                    pass
                client = None
            time.sleep(min(60.0, backoff))
            backoff = min(60.0, backoff * 2)

    if client is not None:
        client.close()
    logger.info("Collector kapatıldı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
