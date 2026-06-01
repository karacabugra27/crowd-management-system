# ─── Stage 1: build ──────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Install deps separately so the layer is cached when only source changes.
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

# Vite reads VITE_* env vars at build time. Pass via --build-arg.
ARG VITE_API_URL=""
ENV VITE_API_URL=$VITE_API_URL

COPY . .
RUN npm run build

# ─── Stage 2: serve via nginx ────────────────────────────────
FROM nginx:1.27-alpine AS runtime

# SPA-friendly nginx config: /api → backend, /ws → backend (upgrade), everything
# else falls back to index.html so client-side routing works on refresh.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Static bundle from the build stage.
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
