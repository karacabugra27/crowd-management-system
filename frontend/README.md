# Crowdly — Web Frontend

**Crowdly**, Akıllı Kampüs Kalabalık Yönetim Sistemi'nin web arayüzüdür. Kampüs alanlarının anlık doluluk durumlarını izlemek ve yönetmek için tasarlanmıştır.

İki bölümden oluşur:

- **Kullanıcı arayüzü** (`/`, `/map`, `/analytics`) — herkese açıktır, giriş gerektirmez.
- **Yönetim paneli** (`/admin`) — yalnızca yetkili yöneticiler erişebilir.

## Teknoloji

- **React 19** + **Vite** — modern build & dev server
- **React Router v6** — yönlendirme
- **Axios** — JWT refresh interceptor ile HTTP istemcisi
- **Recharts** — grafik
- **Leaflet / React-Leaflet** — harita
- **Lucide React** — ikon seti

## Klasör Yapısı

```
frontend/
├── index.html
├── vite.config.js
├── src/
│   ├── api/client.js              # Axios + token yönetimi + auto-refresh
│   ├── components/
│   │   ├── PublicLayout.jsx       # Üst navigasyon (public)
│   │   └── AdminLayout.jsx        # Sidebar (admin)
│   ├── contexts/AuthContext.jsx   # Admin oturum durumu
│   ├── hooks/useWebSocket.js      # Canlı veri için WS bağlantısı
│   ├── pages/
│   │   ├── DashboardPage.jsx      # Public: anlık doluluk kartları
│   │   ├── MapPage.jsx            # Public: kampüs haritası
│   │   ├── AnalyticsPage.jsx      # Public: geçmiş veri grafikleri
│   │   ├── LoginPage.jsx          # Admin girişi
│   │   └── AdminPage.jsx          # Admin: alan / tarayıcı / log yönetimi
│   ├── utils/
│   │   ├── helpers.js             # Durum / format yardımcıları
│   │   └── errors.js              # Backend hatalarını Türkçeye çevirir
│   ├── index.css                  # Tüm tasarım sistemi
│   ├── App.jsx                    # Route tanımları
│   └── main.jsx
```

## Kurulum

```bash
npm install
npm run dev
```

Geliştirme modunda Vite, `/api` ve `/ws` isteklerini varsayılan olarak `http://localhost:8000` (backend) adresine proxy'ler. Farklı bir backend için `.env` dosyasında `VITE_API_URL` tanımlayın.

## Production Build

```bash
npm run build
```

Oluşan `dist/` klasörünü statik bir host'a (Vercel, Netlify, Nginx, vb.) yükleyebilirsiniz.

## Yönetim Paneli

Yönetici hesabı backend tarafında `/api/auth/register` endpoint'i veya `backend/seed_data.py` üzerinden oluşturulur. Web arayüzünden self-service kayıt kapatılmıştır.
