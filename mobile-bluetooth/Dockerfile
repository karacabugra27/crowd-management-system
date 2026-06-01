# Crowdly tarayıcı — APK builder + tiny downloader.
#
# The app talks to physical BLE/Classic Bluetooth radios so it cannot run in a
# browser. Instead this image builds a release APK and serves it over HTTP so
# the user can install it on an Android device:
#
#     http://<host>:5175/crowdly-scanner.apk
#
# First build is slow (~5-10 min) because Flutter pulls Gradle + the Android
# build cache. Layer caching kicks in afterwards.

# ─── Stage 1: build the release APK ──────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS apk-builder

WORKDIR /app

# Pre-fetch dependencies for layer caching.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Build.
COPY . .
RUN flutter pub get \
    && flutter build apk --release

# ─── Stage 2: nginx hosts the APK + a tiny landing page ──────
FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the APK to a predictable filename.
COPY --from=apk-builder \
     /app/build/app/outputs/flutter-apk/app-release.apk \
     /usr/share/nginx/html/crowdly-scanner.apk

# A minimal landing page so visiting http://host:5175 isn't a 404.
RUN printf '%s\n' \
    '<!doctype html><html lang="tr"><head><meta charset="utf-8">' \
    '<title>Crowdly Tarayıcı — APK</title>' \
    '<style>body{font-family:system-ui,sans-serif;background:#0a0a14;color:#e2e8f0;display:grid;place-items:center;min-height:100vh;margin:0}main{max-width:480px;padding:32px;text-align:center}h1{background:linear-gradient(135deg,#818cf8,#60a5fa);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-size:1.8rem;margin:0 0 8px}p{color:#8892a4;line-height:1.6}a.btn{display:inline-block;margin-top:24px;padding:14px 28px;background:linear-gradient(135deg,#6366f1,#818cf8);color:#fff;border-radius:12px;text-decoration:none;font-weight:600}code{background:#181830;padding:2px 6px;border-radius:4px;font-size:.85em}</style>' \
    '</head><body><main><h1>Crowdly Tarayıcı</h1>' \
    '<p>Bluetooth tabanlı kampüs tarayıcı uygulamasını Android cihazınıza indirmek için aşağıdaki butona dokunun.</p>' \
    '<p style="font-size:.85rem">Kurduktan sonra uygulama içinden <code>Sunucu Ayarları</code>nı açıp backend URL ve API anahtarını girin.</p>' \
    '<a class="btn" href="/crowdly-scanner.apk">crowdly-scanner.apk indir</a>' \
    '</main></body></html>' \
    > /usr/share/nginx/html/index.html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
