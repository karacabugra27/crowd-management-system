"""Seed the database with initial campus area data."""
from database import SessionLocal, Area, create_tables

AREAS = [
    {
        "name": "Kütüphane - Ana Salon",
        "short_name": "Kütüphane Ana",
        "capacity": 300,
        "floor": "1. Kat",
        "building": "Kütüphane Binası",
        "icon": "📚",
        "lat": 38.3308,
        "lng": 38.4357,
    },
    {
        "name": "Kütüphane - Sessiz Çalışma",
        "short_name": "Sessiz Çalışma",
        "capacity": 80,
        "floor": "2. Kat",
        "building": "Kütüphane Binası",
        "icon": "🤫",
        "lat": 38.3310,
        "lng": 38.4358,
    },
    {
        "name": "Yemekhane",
        "short_name": "Yemekhane",
        "capacity": 500,
        "floor": "Zemin Kat",
        "building": "Merkez Bina",
        "icon": "🍽️",
        "lat": 38.3315,
        "lng": 38.4350,
    },
    {
        "name": "Bilgisayar Laboratuvarı",
        "short_name": "Bil. Lab.",
        "capacity": 40,
        "floor": "1. Kat",
        "building": "Mühendislik Binası",
        "icon": "💻",
        "lat": 38.3295,
        "lng": 38.4360,
    },
    {
        "name": "Elektronik Laboratuvarı",
        "short_name": "Elek. Lab.",
        "capacity": 30,
        "floor": "2. Kat",
        "building": "Mühendislik Binası",
        "icon": "⚡",
        "lat": 38.3296,
        "lng": 38.4361,
    },
    {
        "name": "Çalışma Odası A",
        "short_name": "Çalışma A",
        "capacity": 20,
        "floor": "3. Kat",
        "building": "Kütüphane Binası",
        "icon": "🏠",
        "lat": 38.3309,
        "lng": 38.4356,
    },
    {
        "name": "Çalışma Odası B",
        "short_name": "Çalışma B",
        "capacity": 20,
        "floor": "3. Kat",
        "building": "Kütüphane Binası",
        "icon": "🏡",
        "lat": 38.3307,
        "lng": 38.4359,
    },
    {
        "name": "Sınıf 101",
        "short_name": "Sınıf 101",
        "capacity": 60,
        "floor": "1. Kat",
        "building": "Merkez Bina",
        "icon": "🎓",
        "lat": 38.3312,
        "lng": 38.4352,
    },
    {
        "name": "Sınıf 201",
        "short_name": "Sınıf 201",
        "capacity": 60,
        "floor": "2. Kat",
        "building": "Merkez Bina",
        "icon": "🎓",
        "lat": 38.3313,
        "lng": 38.4351,
    },
]


def seed():
    create_tables()
    db = SessionLocal()
    try:
        existing = db.query(Area).count()
        if existing > 0:
            print(f"✅ Veritabanında zaten {existing} alan var. Seed atlandı.")
            return

        for area_data in AREAS:
            area = Area(**area_data)
            db.add(area)

        db.commit()
        print(f"✅ {len(AREAS)} kampüs alanı eklendi.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
