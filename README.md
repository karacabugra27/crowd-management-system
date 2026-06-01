# Crowdly — Akıllı Kampüs Kalabalık Yönetim Sistemi

Bluetooth tabanlı tarayıcılardan gelen MAC verilerini kullanarak kampüs alanlarının doluluğunu **gerçek zamanlı** izleyen tam yığın bir sistem.

## Bileşenler

| Bileşen             | Klasör              | Teknoloji                      | Docker servisi         |
| ------------------- | ------------------- | ------------------------------ | ---------------------- |
| Web arayüzü         | `frontend/`         | React 19 + Vite + nginx        | `frontend`             |
| Backend API         | `backend/`          | FastAPI + PostgreSQL + Alembic | `backend`              |
| Mobil kullanıcı app | `mobile-user/`      | Flutter (web build)            | `mobile-user`          |
| Mobil tarayıcı app  | `mobile-bluetooth/` | Flutter (Android APK)          | `mobile-bluetooth-apk` |

---

## Docker ile Çalıştırma

### 1. Sistemi Başlat

```bash
docker compose up --build
```

İlk açılışta backend otomatik olarak şemayı oluşturur ve varsayılan admin hesabını oluşturur.

| Adres                            | Servis                          |
| -------------------------------- | ------------------------------- |
| http://localhost:5173            | Web arayüzü                     |
| http://localhost:5174            | Mobil kullanıcı app (tarayıcı)  |
| http://localhost:8000/docs       | Backend API (Swagger)           |
| localhost:5433                   | PostgreSQL                      |

### 2. Admin Paneline Giriş Yap

http://localhost:5173 → sağ üst **Giriş** → admin hesabıyla oturum aç.

| Alan    | Varsayılan Değer  |
| ------- | ----------------- |
| E-posta | `admin@gmail.com` |
| Şifre   | `123456789`       |

> `.env` dosyasında `SEED_ADMIN_EMAIL` ve `SEED_ADMIN_PASSWORD` ile değiştirilebilir.

### 3. Alan Oluştur

Admin paneli → **Alanlar** sekmesi → **Yeni Alan**:

- **Alan Adı** — örn. `Kütüphane - 1. Kat`
- **Kapasite** — maksimum kişi/cihaz sayısı
- **Kat**, **Enlem/Boylam** — opsiyonel

### 4. Tarayıcı Oluştur ve API Anahtarı Al

Admin paneli → **Tarayıcılar** sekmesi → **Yeni Tarayıcı**:

- Tarayıcıya bir ad ver, oluşturduğun alanı seç.
- Gösterilen **API anahtarını kopyala** — yalnızca bir kez gösterilir.

### 5. Bluetooth Tarayıcı APK'yı Kur (Android Cihaz)

```bash
docker compose --profile apk up --build
```

Build tamamlanınca http://localhost:5175 adresinden APK indir, Android cihaza kur.

Uygulamayı açıp ⚙️ **Sunucu Ayarları**'na gir:

| Alan              | Değer                                          |
| ----------------- | ---------------------------------------------- |
| Backend URL       | `http://<bilgisayarın-ip-adresi>:8000`         |
| API Anahtarı      | Adım 4'te kopyalanan anahtar                   |
| Tarama Alanı      | Listeden alanı seç (backend'den otomatik çeker)|
| Gönderme Aralığı  | Örn. `15` (saniye)                             |
| Otomatik Yükleme  | Açık                                           |

> Emülatörden test ediyorsan URL `http://10.0.2.2:8000` olmalı.

### 6. Taramayı Başlat

Ayarları kaydet → Ana ekranda **Taramayı Başlat** — Bluetooth cihazları algılanır ve doluluk backend'e iletilir.

Web arayüzü ve mobil kullanıcı uygulaması doluluk verilerini gerçek zamanlı gösterir.

---

## Mimari

```
  Tarayıcı APK (mobile-bluetooth)          Kullanıcı (web / mobile-user)
            │                                          │
            │ POST /api/scanner/data                   │ GET /api/occupancy/*
            │ (X-API-Key)                              │ WS /ws/occupancy
            ▼                                          ▼
   ┌──────────────────────────────────────────────────────────┐
   │                   FastAPI (backend)                      │
   │  /api/auth  · /api/areas  · /api/scanner                 │
   │  /api/occupancy  · /api/admin  · /ws/occupancy           │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
                         PostgreSQL
```

---

## Faydalı Komutlar

```bash
# Logları izle
docker compose logs -f backend

# Sadece backend + veritabanı (frontend olmadan)
docker compose up postgres backend

# Veritabanını ve tüm verileri sıfırla
docker compose down -v && docker compose up --build

# Sadece APK build
docker compose --profile apk up mobile-bluetooth-apk --build
```

---

## Lokal Geliştirme (Docker Olmadan)

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # DATABASE_URL'i düzenle
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

### Web Frontend

```bash
cd frontend
npm install
npm run dev   # http://localhost:5173
```

### Flutter

```bash
cd mobile-user        # veya mobile-bluetooth
flutter pub get
flutter run
```
