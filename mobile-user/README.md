# CrowdPulse - Mobil Frontend (Flutter)

Bu proje, **Akıllı Kampüs Kalabalık Yönetim Sistemi**'nin (CrowdPulse) mobil uygulamasını içerir. Web frontend ile birebir aynı tasarım diline (Dark Theme, Glassmorphism) ve API entegrasyonuna sahiptir.

## 🛠 Kullanılan Teknolojiler (Tech Stack)

- **[Flutter 3.x](https://flutter.dev/)**: Cross-platform mobil uygulama framework'ü.
- **[Provider](https://pub.dev/packages/provider)**: State management (web frontend'teki React Context karşılığı).
- **[http](https://pub.dev/packages/http)**: Backend API ile HTTP iletişimi (JWT Token auto-refresh mekanizması ile).
- **[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)**: Token'ların güvenli depolanması (web'deki localStorage karşılığı).
- **[web_socket_channel](https://pub.dev/packages/web_socket_channel)**: WebSocket ile gerçek zamanlı doluluk verileri.
- **[flutter_map](https://pub.dev/packages/flutter_map) & [latlong2](https://pub.dev/packages/latlong2)**: Kampüs haritası (web'deki Leaflet karşılığı).
- **[fl_chart](https://pub.dev/packages/fl_chart)**: Doluluk trend ve cihaz sayısı grafikleri (web'deki Recharts karşılığı).
- **[Google Fonts](https://pub.dev/packages/google_fonts)**: Inter font ailesi (web ile aynı tipografi).

## 📂 Klasör Yapısı

```text
mobilefrontend/
├── lib/
│   ├── core/
│   │   ├── constants.dart      # API endpoint tanımları ve konfigürasyon
│   │   └── theme.dart          # Dark theme, renk paleti (CSS değişkenleri karşılığı)
│   ├── services/
│   │   ├── api_client.dart     # HTTP client, JWT auto-refresh interceptor
│   │   ├── api_service.dart    # Auth, Areas, Occupancy, Admin API sarmalayıcıları
│   │   └── websocket_service.dart # WebSocket bağlantısı, auto-reconnect
│   ├── providers/
│   │   └── auth_provider.dart  # Kullanıcı oturum yönetimi (AuthContext karşılığı)
│   ├── widgets/
│   │   └── common_widgets.dart # GlassCard, StatCard, OccupancyRing, StatusBadge vb.
│   ├── pages/
│   │   ├── login_page.dart     # Giriş/Kayıt ekranı (Glassmorphism, animated orbs)
│   │   ├── dashboard_page.dart # Anlık doluluk kartları ve istatistikler
│   │   ├── map_page.dart       # Flutter Map ile kampüs haritası
│   │   ├── analytics_page.dart # Geçmiş veri grafikleri (fl_chart)
│   │   ├── admin_page.dart     # Alan ve tarayıcı CRUD yönetimi
│   │   └── app_shell.dart      # Ana scaffold, bottom navigation bar
│   ├── utils/
│   │   └── helpers.dart        # Durum renkleri, etiketler, tarih formatlama
│   └── main.dart               # Uygulama giriş noktası, AuthGate
├── android/                    # Android platform ayarları
├── ios/                        # iOS platform ayarları
└── pubspec.yaml                # Bağımlılıklar
```

## 🎨 Tasarım

Tasarım, web frontend ile **birebir aynı** renk paletini ve tasarım dilini kullanır:

- **Koyu Tema**: `#0A0A14` arka plan, glassmorphism efektleri
- **Renk Paleti**: Purple (#818CF8), Blue (#60A5FA), Amber (#FBBF24), Rose (#FB7185)
- **Tipografi**: Google Fonts Inter ailesi
- **Bileşenler**: Ring chart, stat kartları, gradient butonlar, status badge'leri

## 🔐 Kimlik Doğrulama

- JWT token'lar `flutter_secure_storage` ile güvenli şekilde saklanır.
- **Auto-Refresh**: 401 yanıtlarında otomatik token yenileme (web frontend ile aynı mantık).
- Login/Register akışı web ile birebir aynıdır.

## 🚀 Kurulum ve Çalıştırma

### 1. Backend'i başlatın
```bash
cd backend
docker compose up --build -d
```

### 2. API URL'sini ayarlayın

`lib/core/constants.dart` dosyasında `baseUrl`'i ortamınıza göre değiştirin:

```dart
// Android emülatör:
static const String baseUrl = 'http://10.0.2.2:8000';

// iOS simülatör:
static const String baseUrl = 'http://127.0.0.1:8000';

// Gerçek cihaz (bilgisayarınızın IP'si):
static const String baseUrl = 'http://192.168.1.X:8000';
```

### 3. Uygulamayı çalıştırın
```bash
cd mobilefrontend
flutter pub get
flutter run
```

## 📱 Sayfalar

| Sayfa | Açıklama |
|-------|----------|
| **Login** | Glassmorphism tasarımlı giriş/kayıt ekranı |
| **Dashboard** | Anlık doluluk kartları, istatistikler, WebSocket canlı güncelleme |
| **Harita** | Flutter Map ile kampüs üzerinde doluluk işaretçileri |
| **Analitik** | Doluluk trendi (line chart) ve cihaz sayısı (bar chart) grafikleri |
| **Yönetim** | Admin kullanıcılar için alan/tarayıcı CRUD işlemleri |

## 🌍 Production

Production ortamında `lib/core/constants.dart` içindeki `baseUrl`'i gerçek backend URL'iniz ile değiştirin:

```dart
static const String baseUrl = 'https://api.sizin-domain.com';
```
