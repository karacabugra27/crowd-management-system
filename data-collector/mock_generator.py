"""
Mock Wi-Fi AP data generator.

Simulates realistic occupancy patterns for campus areas:
- Peak hours: 08:00–10:00, 12:00–14:00, 17:00–19:00
- Low hours: 00:00–07:00, 22:00–24:00
- Canteen spikes around lunch & dinner time
- Library high on weekdays, low on weekends
"""
import random
import math
from datetime import datetime


# Area configuration: (area_id, capacity, peak_factor, noise_factor)
AREA_CONFIGS = {
    1: {"name": "Kütüphane - Ana Salon",       "capacity": 300, "base": 0.45, "peak_extra": 0.35, "noise": 0.08},
    2: {"name": "Kütüphane - Sessiz Çalışma",  "capacity": 80,  "base": 0.35, "peak_extra": 0.40, "noise": 0.06},
    3: {"name": "Yemekhane",                    "capacity": 500, "base": 0.10, "peak_extra": 0.80, "noise": 0.10},
    4: {"name": "Bilgisayar Laboratuvarı",      "capacity": 40,  "base": 0.20, "peak_extra": 0.55, "noise": 0.08},
    5: {"name": "Elektronik Laboratuvarı",      "capacity": 30,  "base": 0.15, "peak_extra": 0.60, "noise": 0.07},
    6: {"name": "Çalışma Odası A",              "capacity": 20,  "base": 0.25, "peak_extra": 0.45, "noise": 0.10},
    7: {"name": "Çalışma Odası B",              "capacity": 20,  "base": 0.20, "peak_extra": 0.50, "noise": 0.10},
    8: {"name": "Sınıf 101",                    "capacity": 60,  "base": 0.05, "peak_extra": 0.85, "noise": 0.05},
    9: {"name": "Sınıf 201",                    "capacity": 60,  "base": 0.05, "peak_extra": 0.80, "noise": 0.05},
}


def _time_factor(hour: float, area_id: int) -> float:
    """
    Returns a 0–1 multiplier based on time of day.
    Models peak and off-peak hours per area type.
    """
    # Night hours: very low activity
    if hour < 7 or hour > 22:
        return 0.02

    # Canteen (area 3): spikes at 12–13 and 17–18
    if area_id == 3:
        lunch = math.exp(-0.5 * ((hour - 12.5) / 0.8) ** 2)
        dinner = math.exp(-0.5 * ((hour - 18.0) / 0.7) ** 2)
        return max(lunch, dinner, 0.05)

    # Classrooms (area 8, 9): discrete class slots
    if area_id in (8, 9):
        class_slots = [(9, 10), (10, 11), (13, 14), (14, 15), (15, 16)]
        for start, end in class_slots:
            if start <= hour < end:
                return 0.90 + random.uniform(-0.05, 0.05)
        return 0.05

    # Labs (area 4, 5): lab sessions
    if area_id in (4, 5):
        lab_slots = [(9, 11), (13, 15), (15, 17)]
        for start, end in lab_slots:
            if start <= hour < end:
                return 0.75 + random.uniform(-0.1, 0.1)
        return 0.10

    # Library and study rooms: general academic hours
    morning_peak = math.exp(-0.5 * ((hour - 10.5) / 1.5) ** 2) * 0.8
    afternoon    = math.exp(-0.5 * ((hour - 15.0) / 2.0) ** 2) * 0.7
    evening      = math.exp(-0.5 * ((hour - 19.0) / 1.5) ** 2) * 0.5
    return max(morning_peak, afternoon, evening, 0.05)


def _weekend_factor(weekday: int) -> float:
    """Reduced activity on weekends."""
    return 0.30 if weekday >= 5 else 1.0


def generate_readings() -> list[dict]:
    """
    Generate a simulated reading for every area.
    Returns list of {"area_id": int, "device_count": int}.
    """
    now = datetime.now()
    hour = now.hour + now.minute / 60.0
    weekday = now.weekday()  # 0=Monday, 6=Sunday

    readings = []
    for area_id, cfg in AREA_CONFIGS.items():
        tf = _time_factor(hour, area_id)
        wf = _weekend_factor(weekday)

        base_occupancy = cfg["base"] + cfg["peak_extra"] * tf * wf
        # Add realistic Gaussian noise
        noise = random.gauss(0, cfg["noise"])
        occupancy_ratio = max(0.0, min(1.0, base_occupancy + noise))

        # Convert ratio to device count
        device_count = int(occupancy_ratio * cfg["capacity"])

        readings.append({
            "area_id": area_id,
            "device_count": device_count,
            "simulated_pct": round(occupancy_ratio * 100, 1),
            "area_name": cfg["name"],
        })

    return readings


if __name__ == "__main__":
    # Quick test
    print("=== Mock Veri Örneği ===")
    for r in generate_readings():
        bar = "█" * int(r["simulated_pct"] / 5)
        print(f"  {r['area_name']:<35} {r['simulated_pct']:5.1f}%  {bar}")
