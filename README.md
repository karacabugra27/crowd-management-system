# Akıllı Kampüs Kalabalık Yönetim Sistemi

> **Kablosuz ve Mobil Ağlar Dersi Projesi** — İnönü Üniversitesi

Wi-Fi erişim noktalarından toplanan **anonim cihaz verisiyle** kampüs alanlarının doluluk oranını gerçek zamanlı izleyen, web dashboard + Flutter mobil uygulamasıyla gösteren ve eşik aşımında push bildirim gönderen tam yığın sistem.

---

## Özellikler

- **Gerçek zamanlı doluluk** — 30 saniyede bir otomatik güncelleme (WebSocket)
- **Kampüs haritası** — Leaflet üzerinde renkli doluluk göstergesi
- **Geçmiş grafikler** — Son 24 saat / 1 hafta zaman serisi
- **Push bildirim** — Eşik aşımında FCM ile mobil bildirim
- **KVKK uyumlu** — Ham MAC adresi asla kaydedilmez, SHA-256 ile anonimleştirilir
- **Mock simülatör** — Gerçek AP olmadan da çalışır (saate göre gerçekçi veri üretir)

---

## Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| Veri toplama | Python · InfluxDB 2.x |
| Backend API | FastAPI · PostgreSQL · Redis · Celery |
| Web dashboard | React 18 · Vite · Tailwind CSS · Leaflet · Recharts |
| Mobil | Flutter · Riverpod · fl_chart · flutter_map |
| Bildirim | Firebase Cloud Messaging (FCM) |
| Altyapı | Docker · Docker Compose |

---

## Hızlı Başlangıç

**Tek ön koşul: Docker Desktop kurulu olması.**

```bash
# 1. Repoyu klonla
git clone <repo-url>
cd crowd-management-system

# 2. Ortam dosyası oluştur
cp .env.example .env

# 3. Başlat  (ilk seferinde image indirme ~5 dk sürebilir)
docker compose up -d --build
```

Sistem ayağa kalktıktan sonra:

| Adres | Ne açılır |
|---|---|
| http://localhost:3000 | Web dashboard (ana ekran) |
| http://localhost:3000/map | Kampüs haritası |
| http://localhost:3000/history | Doluluk geçmişi grafikleri |
| http://localhost:8000/docs | Swagger — tüm API endpoint'leri |
| http://localhost:8086 | InfluxDB yönetim paneli |

> **Not:** PostgreSQL dışarıdan `5433` portunda erişilebilir  
> (5432 zaten yerel sistemde kullanılıyor olabilir).

---

## Sistem Durumunu Kontrol Et

```bash
# Tüm container'ların durumu
docker compose ps

# Canlı loglar
docker compose logs -f backend collector

# API sağlık kontrolü
curl http://localhost:8000/health
```

---

## Mimari

```
┌─────────────┐   60sn    ┌──────────────┐   zaman serisi   ┌─────────────┐
│  Mock AP    │ ────────▶ │  Collector   │ ───────────────▶ │  InfluxDB   │
│ Simülatörü  │           │  (Python)    │                   └──────┬──────┘
└─────────────┘           └──────────────┘                          │
                                                                     ▼
                          ┌──────────────────────────────────────────────────┐
                          │              FastAPI Backend                      │
                          │  REST · WebSocket · Celery beat · FCM push       │
                          └──────────┬───────────────────────┬───────────────┘
                                     │                       │
                          ┌──────────▼──────────┐  ┌────────▼────────────┐
                          │   Web Dashboard      │  │  Flutter Mobil App  │
                          │  React + Leaflet     │  │  Riverpod + fl_chart│
                          └─────────────────────┘  └─────────────────────┘
```

---

## Kampüs Alanları (İnönü Üniversitesi)

| Alan | ID | Kapasite |
|---|---|---|
| Merkez Kütüphane | `kutuphane` | 300 |
| Yaşam Merkezi Yemekhane | `yemekhane` | 250 |
| Botanik Cafe | `sinif_a` | 80 |
| Esenlik Market | `sinif_b` | 60 |
| Bilgisayar Mühendisliği Lab | `laboratuvar` | 40 |

---

## Doluluk Renk Kodları

| Renk | Durum | Aralık |
|---|---|---|
| 🟢 Yeşil | Boş | 0 – 30% |
| 🟡 Açık yeşil | Az dolu | 31 – 60% |
| 🟡 Sarı | Orta | 61 – 75% |
| 🟠 Turuncu | Yoğun | 76 – 90% |
| 🔴 Kırmızı | Dolu | 91 – 100% |

---

## Push Bildirimleri (Opsiyonel)

Firebase olmadan sistem tamamen çalışır; sadece push bildirimleri gelmez.

Bildirimleri etkinleştirmek için:

1. [Firebase Console](https://console.firebase.google.com) → yeni proje oluştur
2. **Project Settings → Service Accounts → Generate new private key**
3. İndirilen JSON'u proje köküne koy:
   ```bash
   cp ~/Downloads/firebase-xxx.json ./firebase-credentials.json
   ```
4. Flutter (Android) için:
   ```bash
   cp google-services.json mobile/android/app/google-services.json
   ```
5. Container'ları yeniden başlat:
   ```bash
   docker compose restart backend celery-worker
   ```

---

## Flutter Mobil Uygulama

```bash
cd mobile
flutter pub get

# Android emülatör
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simülatör
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Fiziksel cihaz (aynı Wi-Fi ağında)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

---

## Örnek API İstekleri

```bash
# Tüm alanlar
curl http://localhost:8000/api/areas

# Anlık doluluk
curl http://localhost:8000/api/occupancy/live

# Son 24 saatlik geçmiş
curl "http://localhost:8000/api/occupancy/kutuphane/history?hours=24"

# Bildirim tercihi kaydet
curl -X POST http://localhost:8000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "fcm_token": "DEVICE_TOKEN",
    "preferences": [
      {"area_id": "kutuphane", "threshold_pct": 80, "notify_when": "above", "enabled": true}
    ]
  }'
```

---

## Sık Karşılaşılan Sorunlar

**`.env` bulunamadı hatası**
```bash
cp .env.example .env
```

**5432 portu kullanımda**
Normal — PostgreSQL dışarıda `5433` portuna map'lenmiştir, servisler kendi aralarında 5432 kullanır.

**Dashboard'da veri gözükmüyor**
Collector'ın InfluxDB'ye yazdığını kontrol et:
```bash
docker compose logs collector --tail=20
```

**Flutter — `Connection refused` (Android emülatör)**
Android emülatörü host makineye `10.0.2.2` üzerinden erişir, `localhost` değil.

**FCM bildirimleri gelmiyor**
- `firebase-credentials.json` proje kökünde mi?
- `docker compose logs backend | grep Firebase` → initialize mesajını gör

---

## Geliştirici Notları

- `frontend/src/` altındaki değişiklikler **anında** (hot-reload) yansır — rebuild gerekmez
- `backend/` veya `collector/` değişikliklerinde rebuild gerekir:
  ```bash
  docker compose build backend && docker compose up -d backend
  ```
- Yeni kampüs alanı eklemek için `backend/database.py` → `seed_areas` ve `collector/mock_ap.py` → `AREAS` listelerini güncelle

---

## KVKK Notu

Ham MAC adresleri hiçbir zaman kaydedilmez. Collector, cihaz adreslerini SHA-256 + salt ile hash'ler ve yalnızca **alan bazında aggregate** cihaz sayısını depolar. Kullanıcılardan kişisel bilgi (ad, e-posta) alınmaz.

---

## Lisans

Akademik amaçlı geliştirilmiştir. Eğitim ve araştırma için serbestçe kullanılabilir.
