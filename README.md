# Akıllı Kampüs Kalabalık Yönetim Sistemi

Bu proje kampüs içindeki alanların doluluk durumunu takip etmek için geliştirilmiş bir backend API ve admin panel uygulamasından oluşur.

Sistem mantığı kısaca şudur:

1. Kampüsteki fiziksel alanlar backend'e kaydedilir.
2. Scanner cihazları ilgili alanlara bağlanır.
3. Scanner, algıladığı cihaz kimliklerini hashlenmiş şekilde backend'e gönderir.
4. Backend cihaz sayısını, doluluk yüzdesini ve durum etiketini hesaplar.
5. Admin panel bu verileri canlı durum, grafik, konum görünümü ve log ekranlarında gösterir.

> Not: `listener-mobile/` bu çalışma kapsamında kullanılmıyor. Projenin aktif kapsamı `backend/` ve `admin-panel/` dizinleridir.

## Proje Yapısı

```text
crowd-management-system/
├── backend/        # FastAPI + PostgreSQL API
├── admin-panel/    # Vite React admin panel
├── README.md
└── .gitignore
```

## Kullanılan Teknolojiler

Backend:

- FastAPI
- PostgreSQL
- SQLAlchemy async
- Alembic
- JWT auth
- Scanner API key auth
- Docker Compose

Admin panel:

- React
- Vite
- Fetch API
- LocalStorage JWT session
- Responsive admin UI

## Backend Nasıl Çalıştırılır?

Önce Docker Desktop açık olmalı.

```bash
cd backend
docker compose up -d --build
```

Backend'in ayakta olduğunu kontrol etmek için:

```bash
curl http://localhost:8000/health
```

Beklenen cevap:

```json
{"status":"ok","app":"Crowd Management API"}
```

Swagger/OpenAPI arayüzü:

```text
http://localhost:8000/docs
```

Docker container durumunu görmek için:

```bash
cd backend
docker compose ps
```

Backend'i durdurmak için:

```bash
cd backend
docker compose down
```

## Admin Panel Nasıl Çalıştırılır?

Yeni bir terminal açın:

```bash
cd admin-panel
npm install
npm run dev
```

Windows PowerShell script policy hatası verirse:

```bash
npm.cmd install
npm.cmd run dev
```

Vite çalışınca admin panel şu adreste açılır:

```text
http://localhost:5173
```

Admin panel backend adresini şu environment değişkeninden okur:

```text
VITE_API_BASE_URL=http://localhost:8000
```

Bu değer verilmezse varsayılan olarak `http://localhost:8000` kullanılır.

## Admin Girişi

Admin panel JWT token ile çalışır.

Login endpoint:

```text
POST /api/auth/login
```

Başarılı girişten sonra backend `access_token` döndürür. Admin panel bu token'ı `localStorage` içine kaydeder ve sonraki isteklerde şu formatta gönderir:

```text
Authorization: Bearer <token>
```

Admin endpointlerine erişmek için kullanıcının backend tarafında `admin` rolünde olması gerekir.

Örnek kullanıcı oluşturma:

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"AdminPass123!"}'
```

Kullanıcıyı admin yapmak için PostgreSQL içinde:

```bash
docker exec -it campus_postgres psql -U user -d campus
```

Sonra:

```sql
UPDATE users SET role='admin' WHERE email='admin@example.com';
\q
```

## Temel Kavramlar

### Alan

Alan, kampüste takip edilen fiziksel yerdir.

Örnek:

- Kütüphane
- Yemekhane
- Laboratuvar
- Sınıf

Alan kaydında ad, kapasite, kat, aktiflik durumu ve opsiyonel konum bilgisi bulunur.

### Scanner

Scanner, bir alandaki cihaz yoğunluğunu ölçen dinleyici cihazdır.

Scanner bir alana bağlanır ve backend'e hashlenmiş cihaz listesi gönderir. Backend bu listeden tekil cihaz sayısını hesaplar.

Kısaca:

```text
Alan = Ölçülen yer
Scanner = Ölçüm yapan cihaz
```

## Admin Panel Özellikleri

Admin panelde backend'de karşılığı olan ekranlar bulunur:

- Genel Bakış
- Yoğunluk Analizi
- Konum Haritası
- Alanlar
- Scannerlar
- Bluetooth Logları

Backend'de karşılığı olmayan sahte menüler panelde tutulmaz.

### Genel Bakış

Bu ekranda:

- Alan sayısı
- Scanner sayısı
- Canlı tekil cihaz sayısı
- Backend durumu
- Alan yoğunlukları
- Operasyon özeti
- Son scanner durumu
- Son loglar
- Kısa grafik ve konum ön izlemesi

gösterilir.

### Yoğunluk Analizi

Bu ekran şu endpointi kullanır:

```text
GET /api/occupancy/history/{area_id}?hours=24
```

Alan seçilerek belirli saat aralığındaki doluluk geçmişi görüntülenir.

Desteklenen aralıklar:

- Son 6 saat
- Son 12 saat
- Son 24 saat
- Son 3 gün
- Son 7 gün

Grafikte cihaz sayısı, doluluk yüzdesi ve saat bazlı yoğunluk eğilimi gösterilir.

### Konum Haritası

Bu ekran şu endpointi kullanır:

```text
GET /api/occupancy/heatmap
```

Backend alanların konum bilgisini döndürürse admin panel noktaları enlem/boylam değerlerine göre yerleştirir.

Backend bireysel Bluetooth cihaz koordinatı döndürmez. Bu yüzden harita tek tek cihaz konumu değil, alan merkezi bazlı canlı yoğunluk gösterir.

### Alanlar

Kullanılan endpointler:

```text
GET    /api/areas/
POST   /api/areas/
PATCH  /api/areas/{area_id}/toggle-active
DELETE /api/areas/{area_id}
```

Bu ekranda alan oluşturma, listeleme, aktif/pasif yapma ve silme işlemleri yapılır.

### Scannerlar

Kullanılan endpointler:

```text
GET    /api/admin/scanners
POST   /api/admin/scanners
DELETE /api/admin/scanners/{scanner_id}
```

Yeni scanner oluşturulduğunda backend `api_key` değerini yalnızca bir kez döndürür. Bu anahtar scanner cihazının backend'e veri göndermesi için kullanılır.

### Bluetooth Logları

Kullanılan endpoint:

```text
GET /api/admin/logs?area_id=&limit=25
```

Bu ekranda doluluk kayıtları listelenir. Alan filtresi ve kayıt limiti seçilebilir.

## Backend API Özeti

### Sistem

| Method | Endpoint | Açıklama |
|---|---|---|
| GET | `/health` | Backend sağlık kontrolü |

### Auth

| Method | Endpoint | Açıklama |
|---|---|---|
| POST | `/api/auth/register` | Kullanıcı oluşturur |
| POST | `/api/auth/login` | Access/refresh token döndürür |
| POST | `/api/auth/refresh` | Refresh token ile yeni access token döndürür |

### Areas

| Method | Endpoint | Auth | Açıklama |
|---|---|---|---|
| GET | `/api/areas/` | Public | Alanları listeler |
| GET | `/api/areas/{area_id}` | Public | Tek alan detayı |
| POST | `/api/areas/` | Admin | Alan oluşturur |
| PUT | `/api/areas/{area_id}` | Admin | Alan günceller |
| PATCH | `/api/areas/{area_id}/toggle-active` | Admin | Aktif/pasif değiştirir |
| DELETE | `/api/areas/{area_id}` | Admin | Alan siler |

### Occupancy

| Method | Endpoint | Açıklama |
|---|---|---|
| GET | `/api/occupancy/live` | Aktif alanların son doluluk verisi |
| GET | `/api/occupancy/live/{area_id}` | Tek alanın son doluluk verisi |
| GET | `/api/occupancy/history/{area_id}?hours=24` | Belirli saat aralığındaki kayıtlar |
| GET | `/api/occupancy/heatmap` | Konumla zenginleştirilmiş canlı doluluk |
| GET | `/api/occupancy/summary` | Alan bazlı özet istatistik |

### Admin

| Method | Endpoint | Auth | Açıklama |
|---|---|---|---|
| GET | `/api/admin/dashboard` | Admin | Dashboard istatistikleri |
| GET | `/api/admin/scanners` | Admin | Scanner listesi |
| POST | `/api/admin/scanners` | Admin | Scanner oluşturur |
| DELETE | `/api/admin/scanners/{scanner_id}` | Admin | Scanner siler |
| GET | `/api/admin/logs?area_id=&limit=100` | Admin | Doluluk logları |

### Scanner Ingest

Scanner cihazları bu endpoint üzerinden veri gönderir:

```text
POST /api/scanner/data
```

Header:

```text
X-API-Key: <scanner_api_key>
```

Body:

```json
{
  "area_id": 1,
  "mac_hashes": [
    "0000000000000000000000000000000000000000000000000000000000000001",
    "0000000000000000000000000000000000000000000000000000000000000002"
  ]
}
```

Backend aynı hashleri tekilleştirir ve cihaz sayısını hesaplar.

## Veri Akışı

```text
Scanner cihazı
    ↓
POST /api/scanner/data
    ↓
Backend cihaz sayısını ve doluluk yüzdesini hesaplar
    ↓
occupancy_logs tablosuna kayıt atılır
    ↓
Admin panel /api/occupancy/live, /history, /heatmap ve /logs endpointlerinden veriyi okur
```

## Doluluk Hesaplama

Backend doluluk yüzdesini alan kapasitesine göre hesaplar:

```text
occupancy_pct = (device_count / area.capacity) * 100
```

Durum etiketleri:

| Yüzde | Status |
|---|---|
| 0-30 | `empty` |
| 31-60 | `low` |
| 61-75 | `medium` |
| 76-90 | `high` |
| 91-100 | `full` |

## Entegrasyon Notları

Başka bir ekip veya modül bu sisteme entegre olacaksa temel kurallar:

1. Alanlar önce backend'e kaydedilmelidir.
2. Scanner admin panelden veya backend endpointinden oluşturulmalıdır.
3. Scanner oluşturulurken dönen `api_key` güvenli şekilde saklanmalıdır.
4. Scanner veri gönderirken `X-API-Key` header'ı kullanmalıdır.
5. Ham MAC adresi backend'e gönderilmemelidir.
6. Cihaz kimlikleri SHA-256 gibi bir yöntemle anonimleştirilmiş olmalıdır.
7. Gönderilen `mac_hashes` listesinde aynı cihaz birden fazla kez varsa backend tek sayar.

## Gizlilik

Backend ham MAC adresi veya açık cihaz kimliği saklamak için tasarlanmamıştır.

Scanner tarafında cihaz kimlikleri hashlenmeli, backend'e sadece anonim/hashlenmiş değerler gönderilmelidir.

## Test

Backend testleri:

```bash
cd backend
pytest -v
```

Admin panel kontrolü:

```bash
cd admin-panel
npm run lint
npm run build
```

PowerShell kullanıyorsanız:

```bash
npm.cmd run lint
npm.cmd run build
```

## Hızlı Kontrol Listesi

Backend için:

- `docker compose ps` içinde `campus_backend` çalışıyor mu?
- `http://localhost:8000/health` cevap veriyor mu?
- `http://localhost:8000/docs` açılıyor mu?

Admin panel için:

- `npm run dev` çalışıyor mu?
- `http://localhost:5173` açılıyor mu?
- Login sonrası dashboard geliyor mu?
- Backend durumu Online görünüyor mu?
- Veri yoksa panel sahte sayı göstermeden boş durum mesajları gösteriyor mu?
