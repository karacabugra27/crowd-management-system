import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Check if Firebase is already initialized
if not firebase_admin._apps:
    key_path = os.getenv("FIREBASE_KEY_PATH", "serviceAccountKey.json")
    if os.path.exists(key_path):
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
    else:
        # Fallback for environments with GOOGLE_APPLICATION_CREDENTIALS set or defaults
        try:
            firebase_admin.initialize_app()
        except ValueError:
            print("WARNING: Firebase credentials not found. Please set FIREBASE_KEY_PATH or GOOGLE_APPLICATION_CREDENTIALS.")
            # For local testing without a key, we might mock it if needed, but we'll try to initialize anyway
            # In a real app, you need a serviceAccountKey.json
            pass

db = None
try:
    db = firestore.client()
except Exception as e:
    print(f"Firestore initialization error: {e}")

# Helper to get Firestore client
def get_firestore():
    return db

# Seed initial areas if they don't exist
def seed_firestore_areas():
    if not db:
        return
    
    areas_ref = db.collection("areas")
    docs = list(areas_ref.limit(1).stream())
    if len(docs) > 0:
        print("✅ Firestore'da alanlar zaten mevcut.")
        return

    AREAS = [
        {
            "id": "library",
            "name": "Kütüphane - Ana Salon",
            "short_name": "Kütüphane",
            "capacity": 300,
            "floor": "1. Kat",
            "building": "Kütüphane Binası",
            "icon": "📚",
            "is_active": True
        },
        {
            "id": "cafeteria",
            "name": "Yemekhane",
            "short_name": "Yemekhane",
            "capacity": 500,
            "floor": "Zemin Kat",
            "building": "Merkez Bina",
            "icon": "🍽️",
            "is_active": True
        }
    ]

    for area in AREAS:
        doc_id = area.pop("id")
        areas_ref.document(doc_id).set(area)
    
    print("✅ Firestore'a varsayılan alanlar eklendi.")

def save_occupancy_to_firestore(area_id: str, device_count: int, capacity: int):
    if not db:
        return None
        
    pct = 0.0
    if capacity > 0:
        pct = min(round((device_count / capacity) * 100, 1), 100.0)
        
    record = {
        "area_id": area_id,
        "device_count": device_count,
        "occupancy_pct": pct,
        "timestamp": firestore.SERVER_TIMESTAMP
    }
    
    # Add to history
    db.collection("occupancy_history").add(record)
    
    # Update live state in area document
    db.collection("areas").document(area_id).update({
        "live_device_count": device_count,
        "live_occupancy_pct": pct,
        "last_updated": firestore.SERVER_TIMESTAMP
    })
    
    return record
