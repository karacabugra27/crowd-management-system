import axios from "axios";

// In dev, Vite proxy handles /api → backend. In prod, set VITE_API_URL.
const API_BASE = import.meta.env.VITE_API_URL || "";

const api = axios.create({
  baseURL: API_BASE,
  headers: { "Content-Type": "application/json" },
});

/* ─── Token helpers ─────────────────────────────────────── */
export function getAccessToken() {
  return localStorage.getItem("access_token");
}
export function getRefreshToken() {
  return localStorage.getItem("refresh_token");
}
export function setTokens(access, refresh) {
  localStorage.setItem("access_token", access);
  if (refresh) localStorage.setItem("refresh_token", refresh);
}
export function clearTokens() {
  localStorage.removeItem("access_token");
  localStorage.removeItem("refresh_token");
}

/* ─── Request interceptor: attach JWT ───────────────────── */
api.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

/* ─── Response interceptor: auto-refresh on 401 ─────────── */
let isRefreshing = false;
let failedQueue = [];

function processQueue(error, token = null) {
  failedQueue.forEach((prom) => {
    if (error) prom.reject(error);
    else prom.resolve(token);
  });
  failedQueue = [];
}

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const originalRequest = err.config;
    if (err.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          return api(originalRequest);
        });
      }
      originalRequest._retry = true;
      isRefreshing = true;
      const refresh = getRefreshToken();
      if (!refresh) {
        clearTokens();
        window.location.href = "/login";
        return Promise.reject(err);
      }
      try {
        const { data } = await axios.post(`${API_BASE}/api/auth/refresh`, {
          refresh_token: refresh,
        });
        setTokens(data.access_token, null);
        processQueue(null, data.access_token);
        originalRequest.headers.Authorization = `Bearer ${data.access_token}`;
        return api(originalRequest);
      } catch (refreshErr) {
        processQueue(refreshErr, null);
        clearTokens();
        window.location.href = "/login";
        return Promise.reject(refreshErr);
      } finally {
        isRefreshing = false;
      }
    }
    return Promise.reject(err);
  }
);

/* ─── Auth ──────────────────────────────────────────────── */
export const authApi = {
  register: (email, password) =>
    api.post("/api/auth/register", { email, password }),
  login: (email, password) =>
    api.post("/api/auth/login", { email, password }),
  refresh: (refreshToken) =>
    api.post("/api/auth/refresh", { refresh_token: refreshToken }),
};

/* ─── Areas ─────────────────────────────────────────────── */
export const areasApi = {
  list: () => api.get("/api/areas/"),
  get: (id) => api.get(`/api/areas/${id}`),
  create: (data) => api.post("/api/areas/", data),
  update: (id, data) => api.put(`/api/areas/${id}`, data),
  toggleActive: (id) => api.patch(`/api/areas/${id}/toggle-active`),
  delete: (id) => api.delete(`/api/areas/${id}`),
};

/* ─── Occupancy ─────────────────────────────────────────── */
export const occupancyApi = {
  live: () => api.get("/api/occupancy/live"),
  liveOne: (areaId) => api.get(`/api/occupancy/live/${areaId}`),
  history: (areaId, hours = 24) =>
    api.get(`/api/occupancy/history/${areaId}`, { params: { hours } }),
  heatmap: () => api.get("/api/occupancy/heatmap"),
  summary: () => api.get("/api/occupancy/summary"),
};

/* ─── Users ─────────────────────────────────────────────── */
export const usersApi = {
  me: () => api.get("/api/users/me"),
  updateMe: (data) => api.put("/api/users/me", data),
};

/* ─── Admin ─────────────────────────────────────────────── */
export const adminApi = {
  dashboard: () => api.get("/api/admin/dashboard"),
  listScanners: () => api.get("/api/admin/scanners"),
  createScanner: (data) => api.post("/api/admin/scanners", data),
  deleteScanner: (id) => api.delete(`/api/admin/scanners/${id}`),
  logs: (params) => api.get("/api/admin/logs", { params }),
};

/* ─── WebSocket URL builder ─────────────────────────────── */
export function getWsUrl(areaId = null) {
  let wsBase;
  if (API_BASE) {
    // Production: use the configured API URL
    wsBase = API_BASE.replace(/^http/, "ws");
  } else {
    // Dev: use current host (Vite proxy handles /ws)
    const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
    wsBase = `${proto}//${window.location.host}`;
  }
  let url = `${wsBase}/ws/occupancy`;
  if (areaId) url += `?area_id=${areaId}`;
  return url;
}

export default api;
