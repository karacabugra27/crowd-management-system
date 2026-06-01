# CrowdPulse - Web Frontend

Bu proje, **Akıllı Kampüs Kalabalık Yönetim Sistemi**'nin (CrowdPulse) kullanıcı arayüzünü (frontend) içerir. Modern web teknolojileri kullanılarak, kampüs alanlarının doluluk oranlarını gerçek zamanlı izlemek ve yönetmek için tasarlanmıştır. 

Proje, canlıya çıkmaya (production) hazır, modüler ve kolayca genişletilebilir bir mimariyle kodlanmıştır.

## 🛠 Kullanılan Teknolojiler (Tech Stack)

- **[React 18](https://react.dev/)**: Kullanıcı arayüzü kütüphanesi.
- **[Vite](https://vitejs.dev/)**: Yeni nesil, süper hızlı frontend build aracı ve geliştirme sunucusu.
- **[React Router v6](https://reactrouter.com/)**: Sayfalar arası yönlendirme (SPA - Single Page Application) yönetimi.
- **[Axios](https://axios-http.com/)**: Backend API ile HTTP iletişimini kurmak için (JWT Token interceptor'ları ile güçlendirilmiştir).
- **[Recharts](https://recharts.org/)**: Doluluk istatistiklerini çizgi ve bar grafiklerle görselleştirmek için.
- **[Leaflet & React-Leaflet](https://react-leaflet.js.org/)**: Kampüs haritası entegrasyonu ve interaktif doluluk işaretçileri (marker) için.
- **[Lucide React](https://lucide.dev/)**: Modern, tutarlı ve SVG tabanlı ikon seti.

## 📂 Klasör ve Mimari Yapısı

Projeyi geliştirmeye devam edecek geliştiriciler için klasör mimarisi aşağıda özetlenmiştir:

```text
webfrontend/
├── index.html              # Uygulamanın ana HTML giriş noktası
├── vite.config.js          # Vite derleme ve Proxy ayarları
├── .env.example            # Örnek çevre (environment) değişkenleri
├── src/
│   ├── api/
│   │   └── client.js       # Axios ayarları, JWT otomatik yenileme (refresh) mekanizması ve API endpoint sarmalayıcıları.
│   ├── components/
│   │   └── Layout.jsx      # Sabit yan menü (Sidebar) ve mobil duyarlı üst bilgi barı.
│   ├── contexts/
│   │   └── AuthContext.jsx # Kullanıcı giriş/çıkış işlemlerini ve oturum durumunu (state) uygulama genelinde yönetir.
│   ├── hooks/
│   │   └── useWebSocket.js # Backend'den anlık (real-time) kalabalık verisini alan otomatik yeniden bağlanma (reconnect) özellikli hook.
│   ├── pages/
│   │   ├── LoginPage.jsx     # Kayıt Ol ve Giriş Yap ekranı (Glassmorphism tasarım).
│   │   ├── DashboardPage.jsx # Anlık doluluk kartları ve istatistik özetleri.
│   │   ├── MapPage.jsx       # Leaflet tabanlı interaktif kampüs haritası.
│   │   ├── AnalyticsPage.jsx # Seçilen zamana göre geçmiş veri analizi grafikleri.
│   │   └── AdminPage.jsx     # (Sadece Yöneticiler) Yeni alan/tarayıcı ekleme ve silme.
│   ├── utils/
│   │   └── helpers.js      # Doluluk durumuna göre renk/metin hesaplama ve tarih formatlama araçları.
│   ├── index.css           # Tüm uygulamanın tasarım sistemi. CSS Değişkenleri (Variables) ve karanlık (Dark) premium tema.
│   ├── App.jsx             # React Router ayarları (Public, Protected ve Admin rotaları).
│   └── main.jsx            # React uygulamasını DOM'a bağlayan başlangıç noktası.
```

## 🎨 Stil ve Tasarım Kılavuzu (CSS)

Tasarım tamamen **Vanilla CSS** ile `src/index.css` dosyası içinde yazılmıştır. Dışarıdan büyük bir UI kütüphanesi (Bootstrap/Tailwind vs.) kullanılmamış, projeye özel temiz bir tasarım sistemi kurulmuştur.

- **Renk Paleti:** Root değişkenleri (`:root`) kısmında tanımlıdır. Değişiklik yapmak isterseniz `index.css` en üst kısmındaki `--purple`, `--bg-card` vb. değişkenleri düzenleyebilirsiniz.
- **Glassmorphism:** Giriş ekranında ve menülerde bulanık arka plan (backdrop-filter) efektleri kullanılmıştır.
- **Animasyonlar:** Grafik geçişleri, hover efektleri ve bekleme animasyonları akıcı kullanıcı deneyimi (UX) için CSS transition'ları ile eklenmiştir.

## 🔐 Kimlik Doğrulama ve API İstekleri (Axios)

- Tüm HTTP istekleri `src/api/client.js` üzerinden geçer.
- Kullanıcı giriş yaptığında dönen `access_token` ve `refresh_token`, LocalStorage'da saklanır.
- **Auto-Refresh:** Bir API isteği yetkisiz (`401 Unauthorized`) dönerse, Axios interceptor araya girer, `refresh_token`'ı kullanarak yeni bir `access_token` alır ve başarısız olan isteği hissettirmeden tekrar eder.

## 🚀 Kurulum ve Geliştirme (Development)

Sistemi lokal bilgisayarınızda geliştirmek için:

1. **Bağımlılıkları yükleyin:**
   ```bash
   npm install
   ```
2. **Geliştirme sunucusunu başlatın:**
   ```bash
   npm run dev
   ```
   *Not: Geliştirme ortamında Vite, CORS hatalarını önlemek için `.env` içindeki `VITE_API_URL` değeri boş bırakıldığında tüm `/api` ve `/ws` isteklerini otomatik olarak `http://localhost:8000` (Backend) adresine proxy yapar. Konfigürasyonu `vite.config.js` içinde görebilirsiniz.*

## 🌍 Canlıya Alma (Production Deployment)

Projeyi gerçek bir sunucuya yüklemek için (Vercel, Netlify, Nginx, Apache vb.):

1. `.env` dosyası oluşturun (veya mevcut olanı güncelleyin) ve production backend URL'inizi tanımlayın:
   ```env
   VITE_API_URL=https://api.gercek-domain.com
   ```
2. Uygulamayı derleyin:
   ```bash
   npm run build
   ```
3. Derleme tamamlandıktan sonra oluşan `dist` klasörü içindeki tüm statik dosyaları (HTML, CSS, JS) web sunucunuza kopyalayabilirsiniz.
