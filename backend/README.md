# Akıllı Kampüs Kalabalık Yönetim Sistemi — Backend

Kampüsteki alanların doluluğunu Wi-Fi tarayıcıları (scanner) üzerinden takip eden, gerçek zamanlı bir kalabalık yönetim API'si.

## Tech Stack

- **FastAPI** — async HTTP + WebSocket
- **PostgreSQL 16** — birincil veri deposu
- **SQLAlchemy 2.x (async)** + **Alembic** — ORM + migration
- **JWT** (access + refresh) — kullanıcı kimlik doğrulaması
- **API key** — scanner kimlik doğrulaması
- **slowapi** — rate limit
- **Docker + Docker Compose** — geliştirme & dağıtım

## Klasör Yapısı

```
backend/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── dependencies.py
│   ├── models/          # SQLAlchemy modelleri
│   ├── schemas/         # Pydantic şemaları
│   ├── routers/         # HTTP & WebSocket router'ları
│   ├── services/        # İş mantığı
│   └── core/            # security, rate_limiter, exceptions
├── alembic/             # Migration script'leri
├── tests/               # pytest test paketi
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── .env.example
```

## Kurulum

### 1. Docker Compose ile (önerilen)

```bash
cp .env.example .env
# .env dosyasındaki SECRET_KEY'i değiştir
docker compose up --build
```

API: <http://localhost:8000>
Swagger: <http://localhost:8000/docs>
ReDoc: <http://localhost:8000/redoc>

Container açılırken Alembic otomatik olarak `alembic upgrade head` çalıştırır.

### 2. Yerel Python ortamı

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env içindeki DATABASE_URL'i lokal Postgres'ine göre ayarla

alembic upgrade head
uvicorn app.main:app --reload
```

## Veri Tabanı Şeması

| Tablo            | Açıklama                                                  |
| ---------------- | --------------------------------------------------------- |
| `areas`          | İzlenen alan tanımları (kapasite, konum, durum)           |
| `occupancy_logs` | Zaman-serisi doluluk kayıtları, `(area_id, recorded_at)` indeksli |
| `users`          | Kullanıcı (role: `user` / `admin`)                         |
| `scanners`       | Fiziksel tarayıcı cihazları, `api_key` ile kimliklenir    |

## Doluluk Hesaplama

```
occupancy_pct = (device_count / area.capacity) * 100
```

| Yüzde   | Status   |
| ------- | -------- |
| 0–30    | `empty`  |
| 31–60   | `low`    |
| 61–75   | `medium` |
| 76–90   | `high`   |
| 91–100  | `full`   |

## Güvenlik

- **Ham MAC adresi hiçbir zaman yazılmaz.** Scanner istemcileri, MAC adreslerini **SHA-256 ile hash'leyip** gönderir. Backend yalnızca benzersiz hash sayısını saklar.
- Scanner endpoint'i `X-API-Key` header'ı ile korunur (JWT değil).
- Admin endpoint'leri yalnızca `role=admin` olan kullanıcılar erişebilir.
- `mac_hashes` alanı 64 karakter hex string formatında validate edilir.

## API Endpoint'leri

Tüm istekler `Content-Type: application/json` döner.

### Auth — `/api/auth`

| Method | Path        | Body                  | Yanıt              |
| ------ | ----------- | --------------------- | ------------------ |
| POST   | `/register` | `{email, password}`   | `{access_token, refresh_token}` |
| POST   | `/login`    | `{email, password}`   | `{access_token, refresh_token}` |
| POST   | `/refresh`  | `{refresh_token}`     | `{access_token}`   |

```bash
# Register
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "supersecret"}'
```

### Scanner — `/api/scanner`

Header: `X-API-Key: <scanner_api_key>`

```bash
# Örnek: 12 cihaz var
curl -X POST http://localhost:8000/api/scanner/data \
  -H "X-API-Key: csk_xxx..." \
  -H "Content-Type: application/json" \
  -d '{
        "area_id": 1,
        "mac_hashes": [
          "0000000000000000000000000000000000000000000000000000000000000001",
          "0000000000000000000000000000000000000000000000000000000000000002"
        ]
      }'
```

### Areas — `/api/areas`

| Method  | Path                       | Auth     |
| ------- | -------------------------- | -------- |
| GET     | `/`                        | Public   |
| GET     | `/{area_id}`               | Public   |
| POST    | `/`                        | Admin    |
| PUT     | `/{area_id}`               | Admin    |
| PATCH   | `/{area_id}/toggle-active` | Admin    |
| DELETE  | `/{area_id}`               | Admin    |

### Occupancy — `/api/occupancy`

| Method | Path                        | Açıklama                                        |
| ------ | --------------------------- | ----------------------------------------------- |
| GET    | `/live`                     | Tüm aktif alanlar için son doluluk              |
| GET    | `/live/{area_id}`           | Tek alan için son doluluk                       |
| GET    | `/history/{area_id}?hours=24` | Belirli saat aralığındaki log kayıtları       |
| GET    | `/heatmap`                  | Konumla zenginleştirilmiş anlık doluluk listesi |
| GET    | `/summary`                  | Alan bazında özet istatistikler                 |

### Users — `/api/users`

| Method | Path  | Auth |
| ------ | ----- | ---- |
| GET    | `/me` | JWT  |
| PUT    | `/me` | JWT  |

### Admin — `/api/admin`

| Method | Path                       | Auth  |
| ------ | -------------------------- | ----- |
| GET    | `/dashboard`               | Admin |
| GET    | `/scanners`                | Admin |
| POST   | `/scanners`                | Admin |
| DELETE | `/scanners/{scanner_id}`   | Admin |
| GET    | `/logs?area_id=&limit=100` | Admin |

`POST /api/admin/scanners` çağrısı **`api_key`** alanını yalnızca **bir kez** döndürür — istemci tarafında güvenli bir yerde saklanmalıdır.

### WebSocket — `/ws/occupancy`

```javascript
// Tüm alanlar
const ws = new WebSocket("ws://localhost:8000/ws/occupancy");

// Sadece area_id=3
const ws3 = new WebSocket("ws://localhost:8000/ws/occupancy?area_id=3");

ws.onmessage = (e) => {
  const data = JSON.parse(e.data);
  // {area_id, area_name, device_count, occupancy_pct, status, recorded_at}
};
```

Scanner verisi geldikçe bağlı tüm istemcilere broadcast yapılır.

## Migration

```bash
# Yeni migration oluştur
alembic revision --autogenerate -m "describe change"

# Uygula
alembic upgrade head

# Geri al
alembic downgrade -1
```

## Test

```bash
pip install -r requirements.txt
pytest -v
```

Testler in-memory SQLite kullanır — Postgres'e gerek yoktur.

## Admin Kullanıcı Oluşturma

Postgres içinde manuel olarak rol değiştirilebilir:

```sql
UPDATE users SET role = 'admin' WHERE email = 'admin@example.com';
```

## Konfigürasyon

| Env değişkeni                  | Default                                                      | Açıklama                       |
| ------------------------------ | ------------------------------------------------------------ | ------------------------------ |
| `DATABASE_URL`                 | `postgresql+asyncpg://user:pass@postgres:5432/campus`        | Async DSN                      |
| `SECRET_KEY`                   | —                                                            | JWT imzalama anahtarı          |
| `ALGORITHM`                    | `HS256`                                                      | JWT algoritması                |
| `ACCESS_TOKEN_EXPIRE_MINUTES`  | `30`                                                         | Access token süresi            |
| `REFRESH_TOKEN_EXPIRE_DAYS`    | `7`                                                          | Refresh token süresi           |
| `CORS_ORIGINS`                 | `*`                                                          | Virgül ile ayrılmış origin listesi |
| `RATE_LIMIT_PER_MINUTE`        | `60`                                                         | Dakika başı global rate limit  |
