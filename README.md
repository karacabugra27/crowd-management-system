# Crowdly — Akıllı Kampüs Kalabalık Yönetim Sistemi

Bluetooth tabanlı tarayıcılardan gelen MAC verilerini kullanarak kampüs alanlarının doluluğunu **gerçek zamanlı** izleyen tam yığın bir sistem.

## Bileşenler

| Bileşen              | Klasör              | Teknoloji                      | Docker servisi          |
| -------------------- | ------------------- | ------------------------------ | ----------------------- |
| Web arayüzü          | `frontend/`         | React 19 + Vite + nginx        | `frontend`              |
| Backend API          | `backend/`          | FastAPI + PostgreSQL + Alembic | `backend`               |
| Mobil kullanıcı app  | `mobile-user/`      | Flutter (web build edilir)     | `mobile-user`           |
| Mobil tarayıcı app   | `mobile-bluetooth/` | Flutter (Android APK)          | `mobile-bluetooth-apk`  |

## Tek Komutla Çalıştırma

Gereksinim: Docker Desktop (veya docker engine + docker compose v2).

```bash
cp .env.example .env       # gerekirse düzenle
docker compose up --build
```

Bu komut **Postgres + Backend + Web frontend + Mobil web build**'i ayağa kaldırır.

Hazır olduğunda:

- **Web arayüzü**         → http://localhost:5173
- **Mobil kullanıcı app** → http://localhost:5174 (Flutter web build'i)
- **Backend API**         → http://localhost:8000 (Swagger: `/docs`)
- **Postgres**            → `localhost:5433`

İlk açılışta otomatik olarak çalışan backend adımları:

1. `alembic upgrade head` — şema oluşturma
2. `python -m app.seed` — varsayılan admin + başlangıç alanları
3. `uvicorn` — API başlatılır

### Bluetooth tarayıcı APK (opsiyonel)

`mobile-bluetooth` gerçek Bluetooth donanımına erişir, bu yüzden tarayıcıda çalıştırılamaz — Android cihaza kurulmak üzere APK olarak derlenir. İlk build uzun sürer (~10 dk, Gradle + Android SDK indirir), bu yüzden opt-in profile altında:

```bash
docker compose --profile apk up --build
```

Sonra: http://localhost:5175 → APK indirme sayfası açılır. Android cihazda APK'yı kurun, açıp ⚙️ **Sunucu Ayarları**'ndan backend URL, API anahtarı ve alan ID girin. (API anahtarı için web panelinden bir Scanner oluşturun.)

## Varsayılan Admin

| Alan      | Değer              |
| --------- | ------------------ |
| E-posta   | `admin@gmail.com`  |
| Şifre     | `123456789`        |

`.env` üzerinden `SEED_ADMIN_EMAIL` ve `SEED_ADMIN_PASSWORD` ile değiştirilebilir. Seed her container start'ta çalışır; mevcut admin'in şifresi `.env`'deki değere senkronlanır (volume silmeden şifre değişikliği için pratik).

Giriş için: http://localhost:5173/admin/login

## Mimari

```
  Tarayıcı APK (mobile-bluetooth)            Kullanıcı (web veya mobile-user)
            │                                            │
            │ POST /api/scanner/data                     │ GET /api/occupancy/*
            │ (X-API-Key header)                         │ WS /ws/occupancy
            ▼                                            ▼
   ┌────────────────────────────────────────────────────────────┐
   │                    FastAPI (backend)                       │
   │  · /api/auth     · /api/areas                              │
   │  · /api/scanner  · /api/occupancy                          │
   │  · /api/admin    · /ws/occupancy                           │
   └────────────────────────────────────────────────────────────┘
                              │
                              ▼
                         PostgreSQL
```

## Lokal Geliştirme (Docker olmadan)

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env       # DATABASE_URL'i lokal postgres'a göre düzenle
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

### Web frontend

```bash
cd frontend
npm install
npm run dev        # http://localhost:5173, /api ve /ws proxy'lenir
```

### Flutter (mobile-user veya mobile-bluetooth)

```bash
cd mobile-user           # ya da mobile-bluetooth
flutter pub get
flutter run              # cihaz/emülatör seçilir
```

mobile-user için ayar ekranından, mobile-bluetooth için ⚙️ Sunucu Ayarları'ndan backend URL'sini ayarlayın.

## Faydalı Komutlar

```bash
docker compose logs -f backend                 # backend loglarını izle
docker compose exec backend python -m app.seed # seed'i yeniden çalıştır
docker compose down -v                         # konteynerleri + DB volume'u sıfırla
docker compose --profile apk up mobile-bluetooth-apk --build   # sadece APK build
```
