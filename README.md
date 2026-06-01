# Crowdly — Akıllı Kampüs Kalabalık Yönetim Sistemi

Bluetooth tabanlı tarayıcılardan gelen MAC verilerini kullanarak kampüs alanlarının doluluğunu **gerçek zamanlı** izleyen tam yığın bir sistem.

## Bileşenler

| Bileşen            | Klasör              | Teknoloji                      |
| ------------------ | ------------------- | ------------------------------ |
| Web arayüzü        | `frontend/`         | React 19 + Vite + nginx        |
| Backend API        | `backend/`          | FastAPI + PostgreSQL + Alembic |
| Mobil tarayıcı     | `mobile-bluetooth/` | Flutter (BLE + Classic BT)     |

## Tek Komutla Çalıştırma

Gereksinim: Docker Desktop (veya docker engine + docker compose v2).

```bash
cp .env.example .env       # gerekirse düzenle
docker compose up --build
```

Hazır olduğunda:

- **Web arayüzü** → http://localhost:5173
- **Backend API** → http://localhost:8000 (Swagger: `/docs`)
- **Postgres** → `localhost:5433`

İlk açılışta otomatik olarak çalışan adımlar:

1. `alembic upgrade head` — şema oluşturma
2. `python -m app.seed` — varsayılan admin + başlangıç alanları
3. `uvicorn` — API başlatılır

## Varsayılan Admin

| Alan      | Değer                  |
| --------- | ---------------------- |
| E-posta   | `admin@crowdly.local`  |
| Şifre     | `crowdly123`           |

`.env` üzerinden `SEED_ADMIN_EMAIL` ve `SEED_ADMIN_PASSWORD` değişkenleri ile değiştirilebilir. Admin yalnızca veritabanında hiç admin yokken oluşturulur — re-build güvenli.

Giriş için: http://localhost:5173/admin/login

## Mimari

```
  Tarayıcı (mobil)                Kullanıcı (web)
        │                              │
        │ POST /api/scanner/data       │ GET /api/occupancy/*
        ▼                              ▼
  ┌──────────────────────────────────────────┐
  │             FastAPI (backend)            │
  │  · /api/auth     · /api/areas            │
  │  · /api/scanner  · /api/occupancy        │
  │  · /api/admin    · /ws/occupancy         │
  └──────────────────────────────────────────┘
                       │
                       ▼
               PostgreSQL
```

## Geliştirme

### Backend (lokal, Docker olmadan)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env       # DATABASE_URL'i lokal postgres'a göre düzenle
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

### Frontend (lokal)

```bash
cd frontend
npm install
npm run dev        # http://localhost:5173, /api ve /ws proxy'lenir
```

`.env` içinde `VITE_API_URL=http://localhost:8000` belirtebilirsin (boş bırakırsan proxy üzerinden gider).

### Mobil

```bash
cd mobile-bluetooth
flutter pub get
flutter run
```

İlk çalıştırmada uygulama içindeki ⚙️ **Sunucu Ayarları** ekranından backend URL, API anahtarı ve alan ID girilmelidir. Admin panelinden tarayıcı oluşturup üretilen anahtarı buraya kopyalayın.

## Faydalı Komutlar

```bash
docker compose logs -f backend     # backend loglarını izle
docker compose exec backend python -m app.seed     # seed'i yeniden çalıştır
docker compose down -v             # konteynerleri + DB volume'u sıfırla
```
