# CrowdPulse - Akıllı Kampüs Kalabalık Yönetim Sistemi

Akıllı Kampüs Kalabalık Yönetim Sistemi Kablosuz ve Mobil Ağlar Dersi Projesi. Bu sistem, kampüs içindeki çeşitli alanların (kütüphane, yemekhane, spor salonu vb.) doluluk oranlarını Wi-Fi tarayıcıları (scanner cihazları) yardımıyla gerçek zamanlı olarak izler ve modern bir arayüz üzerinden görselleştirir.

## Proje Bileşenleri

Proje, iki temel bileşenden oluşmaktadır:

1. **[Backend (FastAPI)](./backend/README.md)**: Kalabalık verilerini işleyen, cihazlardan gelen verileri alan, JWT kimlik doğrulaması sunan ve WebSocket ile gerçek zamanlı güncellemeler sağlayan Python (FastAPI) tabanlı sistem. Veritabanı olarak PostgreSQL kullanır.
2. **[Web Frontend (React + Vite)](./webfrontend/)**: Backend'e entegre çalışan, anlık doluluk oranlarını gösteren, interaktif harita (Leaflet) desteğine ve analitik raporlamalara (Recharts) sahip modern (Glassmorphism tasarım) yönetim arayüzü.

## Başlangıç ve Kurulum

Projeyi canlıya almak veya geliştirme ortamında çalıştırmak için aşağıdaki adımları izleyin.

### 1. Backend'i Başlatma

Backend ve PostgreSQL veritabanı Docker üzerinden çalıştırılır.

```bash
cd backend

# Örnek ortam değişkenleri dosyasını kopyalayın
cp .env.example .env

# Docker container'larını başlatın (veritabanı ve backend ayağa kalkar)
docker compose up --build -d
```
> Backend API `http://localhost:8000` adresinde çalışacaktır. Detaylı bilgi için [Backend README](./backend/README.md) dosyasını inceleyebilirsiniz.

### 2. Frontend'i Başlatma

Frontend, React ve Vite kullanılarak geliştirilmiştir.

```bash
cd webfrontend

# Bağımlılıkları yükleyin
npm install

# Geliştirme sunucusunu başlatın
npm run dev
```
> Frontend geliştirme ortamında `http://localhost:5173` adresinde çalışır. Dev ortamında `.env` içinde `VITE_API_URL` boş bırakılır; Vite'in kendi proxy'si istekleri otomatik olarak `http://localhost:8000`'e yönlendirir (Bkz: `webfrontend/vite.config.js`).

## Canlıya Çıkış (Production)

Bu sistem baştan itibaren **canlıya çıkmaya hazır (production-ready)** mimaride tasarlanmıştır:

### Backend Production Ayarları
- `backend/.env` içindeki `SECRET_KEY` değerini güvenli, uzun ve rastgele bir string ile değiştirin.
- `APP_ENV=production` yapın.
- Veritabanı şifrelerini güncelleyin.
- SSL sertifikası (HTTPS) ayarlamaları için bir Nginx veya Traefik reverse proxy kullanılması önerilir.

### Frontend Production Ayarları
Frontend'i statik dosyalara derleyip sunucunuza (Nginx, Vercel, Netlify, vb.) yükleyebilirsiniz.

1. `webfrontend/.env` dosyasını oluşturup canlı backend URL'nizi girin:
   ```env
   VITE_API_URL=https://api.sizin-kampus-domaininiz.com
   ```
2. Build alın:
   ```bash
   cd webfrontend
   npm run build
   ```
3. `webfrontend/dist` klasörü içindeki tüm dosyalar sizin canlıya çıkacak statik (HTML/CSS/JS) dosyalarınızdır. Nginx, Apache veya herhangi bir statik sunucuda barındırabilirsiniz.

## Özellikler

- **Gerçek Zamanlı Takip:** WebSocket bağlantısı sayesinde ekrana yansıyan anlık (live) veriler.
- **Harita Desteği:** Alanları Leaflet haritası üzerinde coğrafi konumlarıyla izleme.
- **Güvenlik:** Kullanıcılar için JWT tabanlı koruma, scanner cihazlar için benzersiz API key (şifrelenmiş MAC adresi doğrulaması) ile yüksek güvenlik.
- **Performans Analitiği:** Recharts kullanılarak sunulan doluluk trendi ve cihaz sayısı istatistikleri.
- **Tasarım (UI/UX):** Tamamen modern, karanlık tema (dark mode) ve glassmorphism tabanlı zengin arayüz.
