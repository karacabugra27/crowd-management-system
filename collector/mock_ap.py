"""
mock_ap.py
----------
Gerçek Wi-Fi erişim noktası bağlantısı bulunmadığı durumda kullanılan
simülatör. Saat dilimine göre gerçekçi cihaz sayıları üretir ve her
cihaz için sentetik bir MAC adresi döndürür.

Tipik gün senaryosu:
- 00:00-07:00 : çok az kullanıcı (gece)
- 07:00-09:00 : yükselen trafik (sabah)
- 09:00-12:00 : yüksek trafik (ders/iş saatleri)
- 12:00-13:30 : yemekhanede pik, sınıflarda düşüş
- 13:30-17:00 : tekrar yüksek
- 17:00-19:00 : düşüş
- 19:00-22:00 : kütüphanede pik
- 22:00-00:00 : azalma
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Area:
    """Bir kampüs alanını temsil eder."""

    id: str
    name: str
    capacity: int
    # Lat/lng kampüs harita için sahte koordinatlar
    latitude: float
    longitude: float
    floor: int


# Kampüs alanları - prod'da PostgreSQL'den okunabilir, burada referans olarak
# tutulur ve backend tarafında da aynı liste seed edilir.
# İnönü Üniversitesi Battalgazi Kampüsü, Malatya
AREAS: list[Area] = [
    Area("kutuphane",   "Merkez Kütüphane",           300, 38.3334154152037, 38.43970380767402, 1),
    Area("yemekhane",   "Yaşam Merkezi Yemekhane",    250, 38.33149165728883, 38.43520602908551, 0),
    Area("sinif_a",     "Botanik Cafe",                 80, 38.33105739256537, 38.44714016205789, 0),
    Area("sinif_b",     "Esenlik Market",               60, 38.33102796418538, 38.44461414379356, 0),
    Area("laboratuvar", "Bilgisayar Mühendisliği Lab",  40, 38.3322, 38.4410, 2),
]


def _time_of_day_multiplier(hour: int, area_id: str) -> float:
    """
    Saat ve alana göre doluluk oranı çarpanı (0.0 - 1.0).

    Her alan farklı saatlerde pik yapar. Bu fonksiyon gerçek dünyaya
    yakın bir dağılım üretir.
    """
    # Saat bazlı temel profil (tüm alanlar için ortak)
    if 0 <= hour < 7:
        base = 0.03
    elif 7 <= hour < 9:
        base = 0.25
    elif 9 <= hour < 12:
        base = 0.70
    elif 12 <= hour < 13:
        base = 0.55
    elif 13 <= hour < 17:
        base = 0.75
    elif 17 <= hour < 19:
        base = 0.45
    elif 19 <= hour < 22:
        base = 0.40
    else:
        base = 0.15

    # Alan-spesifik düzeltmeler
    adjustments = {
        # Yemekhane: 12:00-13:30 ve 18:00-19:30 pik
        "yemekhane": 1.4 if 12 <= hour < 14 else (1.3 if 18 <= hour < 20 else 0.4),
        # Kütüphane: akşam pik (sınav dönemi etkisi)
        "kutuphane": 1.3 if 19 <= hour < 23 else (1.1 if 9 <= hour < 18 else 0.6),
        # Sınıflar: sadece ders saatlerinde dolu
        "sinif_a": 1.2 if 9 <= hour < 17 else 0.1,
        "sinif_b": 1.2 if 9 <= hour < 17 else 0.1,
        # Lab: gün boyu orta yoğunlukta
        "laboratuvar": 1.1 if 10 <= hour < 18 else 0.3,
    }
    multiplier = base * adjustments.get(area_id, 1.0)
    return max(0.0, min(1.0, multiplier))


def _generate_fake_mac() -> str:
    """RFC-uyumlu lokal-yönetilen sentetik MAC adresi üretir."""
    # İlk byte'da locally administered bit (0x02) setli, multicast bit setli değil
    first_byte = random.choice([0x02, 0x06, 0x0A, 0x0E])
    parts = [first_byte] + [random.randint(0, 255) for _ in range(5)]
    return ":".join(f"{b:02X}" for b in parts)


def get_areas() -> list[Area]:
    """Tanımlı kampüs alanlarını döndürür."""
    return list(AREAS)


def simulate_devices(area: Area, now: datetime | None = None) -> list[str]:
    """
    Verilen alan için gerçekçi sayıda sentetik MAC adresi üretir.

    Args:
        area: Doluluk simülasyonu yapılacak alan
        now: Simülasyon zaman damgası (varsayılan: şimdi)

    Returns:
        Sentetik MAC adresleri listesi (anonimleştirilmeden önceki ham veri)
    """
    if now is None:
        now = datetime.now()

    multiplier = _time_of_day_multiplier(now.hour, area.id)
    # Rastgele dalgalanma: +/- %15
    jitter = random.uniform(0.85, 1.15)
    target_count = int(area.capacity * multiplier * jitter)
    target_count = max(0, min(area.capacity + 10, target_count))
    return [_generate_fake_mac() for _ in range(target_count)]
