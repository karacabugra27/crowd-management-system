"""
influx_service.py
-----------------
InfluxDB sorgu servisi — anlık ve geçmiş doluluk verilerini okur.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from influxdb_client import InfluxDBClient

from config import get_settings
from models import OccupancyHistoryPoint, OccupancyStatus

logger = logging.getLogger(__name__)
_settings = get_settings()


def occupancy_status(pct: float) -> OccupancyStatus:
    """Doluluk yüzdesini renk kodlu duruma çevirir."""
    if pct <= 30:
        return "empty"
    if pct <= 60:
        return "low"
    if pct <= 75:
        return "medium"
    if pct <= 90:
        return "high"
    return "full"


class InfluxService:
    """InfluxDB ile etkileşim sağlayan servis sınıfı."""

    def __init__(self) -> None:
        self._client = InfluxDBClient(
            url=_settings.influxdb_url,
            token=_settings.influxdb_token,
            org=_settings.influxdb_org,
        )
        self._query_api = self._client.query_api()
        self._bucket = _settings.influxdb_bucket
        self._org = _settings.influxdb_org

    def close(self) -> None:
        self._client.close()

    # ------------------------------------------------------------------
    # Anlık veri
    # ------------------------------------------------------------------
    def get_latest_for_all(self) -> dict[str, dict[str, Any]]:
        """
        Tüm alanlar için en son doluluk ölçümünü döndürür.

        Returns:
            {area_id: {device_count, occupancy_pct, capacity, last_updated}}
        """
        flux = f"""
        from(bucket: "{self._bucket}")
          |> range(start: -1h)
          |> filter(fn: (r) => r._measurement == "occupancy")
          |> filter(fn: (r) => r._field == "device_count" or r._field == "occupancy_pct" or r._field == "capacity")
          |> last()
          |> pivot(rowKey: ["_time", "area_id", "area_name"], columnKey: ["_field"], valueColumn: "_value")
        """
        result: dict[str, dict[str, Any]] = {}
        try:
            tables = self._query_api.query(flux, org=self._org)
            for table in tables:
                for record in table.records:
                    area_id = record.values.get("area_id")
                    if not area_id:
                        continue
                    result[area_id] = {
                        "device_count": int(record.values.get("device_count", 0) or 0),
                        "occupancy_pct": float(
                            record.values.get("occupancy_pct", 0.0) or 0.0
                        ),
                        "capacity": int(record.values.get("capacity", 0) or 0),
                        "last_updated": record.get_time(),
                    }
        except Exception:  # noqa: BLE001
            logger.exception("InfluxDB get_latest_for_all hata")
        return result

    # ------------------------------------------------------------------
    # Geçmiş veri
    # ------------------------------------------------------------------
    def get_history(
        self, area_id: str, hours: int = 24, aggregate_minutes: int = 5
    ) -> list[OccupancyHistoryPoint]:
        """
        Bir alanın son N saatlik doluluk geçmişini döndürür.

        Args:
            area_id: Alan kimliği
            hours: Geriye gidilecek saat sayısı (max 168 = 1 hafta)
            aggregate_minutes: Aggregate window (dakika)

        Returns:
            Zaman sıralı OccupancyHistoryPoint listesi
        """
        hours = max(1, min(168, hours))
        aggregate_minutes = max(1, min(60, aggregate_minutes))

        flux = f"""
        from(bucket: "{self._bucket}")
          |> range(start: -{hours}h)
          |> filter(fn: (r) => r._measurement == "occupancy")
          |> filter(fn: (r) => r.area_id == "{area_id}")
          |> filter(fn: (r) => r._field == "device_count" or r._field == "occupancy_pct")
          |> aggregateWindow(every: {aggregate_minutes}m, fn: mean, createEmpty: false)
          |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
          |> sort(columns: ["_time"])
        """
        points: list[OccupancyHistoryPoint] = []
        try:
            tables = self._query_api.query(flux, org=self._org)
            for table in tables:
                for record in table.records:
                    ts: datetime | None = record.get_time()
                    if ts is None:
                        continue
                    points.append(
                        OccupancyHistoryPoint(
                            timestamp=ts,
                            device_count=int(
                                record.values.get("device_count", 0) or 0
                            ),
                            occupancy_pct=round(
                                float(record.values.get("occupancy_pct", 0.0) or 0.0),
                                2,
                            ),
                        )
                    )
        except Exception:  # noqa: BLE001
            logger.exception("InfluxDB get_history hata (area=%s)", area_id)
        return points


# Modül seviyesinde tek instance (FastAPI lifespan'da kapatılır)
_instance: InfluxService | None = None


def get_influx_service() -> InfluxService:
    """Singleton InfluxService instance."""
    global _instance
    if _instance is None:
        _instance = InfluxService()
    return _instance


def shutdown_influx_service() -> None:
    """Uygulama kapanışında InfluxDB bağlantısını kapatır."""
    global _instance
    if _instance is not None:
        _instance.close()
        _instance = None
