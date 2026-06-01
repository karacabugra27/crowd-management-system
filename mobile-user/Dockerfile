# ─── Stage 1: Flutter web build ───────────────────────────────
# cirruslabs ships a maintained Flutter image (Dart SDK + tooling + web).
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app

# Dep resolution layer — cached unless pubspec changes.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Now copy the rest and build the release web bundle.
COPY . .
RUN flutter pub get \
    && flutter build web --release --no-tree-shake-icons

# ─── Stage 2: nginx serves the static bundle ──────────────────
FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=flutter-builder /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
