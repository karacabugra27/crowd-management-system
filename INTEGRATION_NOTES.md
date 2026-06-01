# Integration Notes

## Branch amacı

Bu çalışma Ruhan'ın admin panelini gerçek backend endpointlerine bağlar, paneldeki gizli/sahte sayıları kaldırır, açık etiketli Demo Modu ekler ve Emre'nin dinleyici mobil uygulamasını ayrı bir `listener-mobile/` modülü olarak konumlandırır.

Backend koduna dokunulmadı.

## Backend çalıştırma

```bash
cd backend
docker compose up -d --build
curl http://localhost:8000/health
```

Beklenen health yanıtı:

```json
{"status":"ok","app":"Crowd Management API"}
```

## Admin panel çalıştırma

```bash
cd admin-panel
npm install
npm run dev
```

Admin panel backend adresini Vite env üzerinden okur:

```bash
VITE_API_BASE_URL=http://localhost:8000
```

Token `localStorage.access_token` içinde tutulur ve isteklerde şu header kullanılır:

```text
Authorization: Bearer <token>
```

## Admin panel endpointleri

Backend kodundan doğrulanan endpointler:

- `GET /health`
- `POST /api/auth/login`
- `GET /api/admin/dashboard`
- `GET /api/areas/`
- `GET /api/admin/scanners`
- `GET /api/occupancy/live`
- `GET /api/admin/logs?limit=8`

`/api/admin/*` endpointleri admin JWT ister. `/api/areas/` ve `/api/occupancy/live` public okunabilir endpointlerdir.

## Veri davranışı

Varsayılan mod Gerçek Veri modudur. Backend boşsa panel uydurma sayı göstermez:

- alan ve scanner sayıları `0` olabilir,
- canlı doluluk yoksa `Henüz canlı doluluk kaydı yok`,
- scanner yoksa `Kayıtlı scanner yok`,
- log yoksa `Henüz doluluk logu yok` mesajı görünür.

Demo Modu kullanıcı tarafından açılır. Açıldığında panelde açıkça `Demo Modu Aktif` yazılır ve Kütüphane, Yemekhane, Laboratuvar, Sınıf 204, Scanner-01 ve Scanner-02 örnek kayıtları gösterilir.

## Listener mobile

Emre'nin dinleyici mobil uygulaması ayrı modül olarak buraya eklendi:

```text
listener-mobile/
```

Çalıştırma:

```bash
cd listener-mobile
flutter pub get
flutter run
```

Mevcut durum:

- Uygulama yerel cihaz sayımını `ip neigh` üzerinden deneysel olarak yapar.
- Backend'e otomatik veri göndermez.
- Önceki eski `/occupancy/ingest` tahmini endpoint kullanımı kaldırıldı.
- Doğrulanmış scanner ingest endpointi `POST /api/scanner/data` şeklindedir.
- Bu endpoint `X-API-Key` ve `area_id` + `mac_hashes` ister.
- Ham MAC adresi veya cihaz kimliği backend'e düz metin gönderilmemelidir.

`listener-mobile/lib/services/api_service.dart` dosyasında sadece hazır bir helper vardır. Bu helper, yalnızca listener SHA-256 hash listesi üretebildiğinde ve admin/backend üzerinden scanner API key alındığında kullanılmalıdır.

## Notlar

- Backend migration, Dockerfile, requirements ve backend app kodları değiştirilmedi.
- Admin log endpointinin mevcut şeması `area_id` veya scanner bilgisi döndürmüyor; panel loglarda sadece backend'in sağladığı cihaz sayısı, zaman, doluluk yüzdesi ve durum bilgisini gösterir.
- `node_modules/`, `dist/`, `.env`, Python cache/venv ve Flutter build çıktıları `.gitignore` kapsamındadır.
