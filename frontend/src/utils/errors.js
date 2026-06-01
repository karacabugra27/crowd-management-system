/**
 * Convert an axios/fetch error into a user-friendly Turkish message.
 *
 * Handles:
 *   - Network failures (no response from backend)
 *   - HTTP status codes (400/401/403/404/409/422/429/500/503)
 *   - FastAPI's `detail` payload (string, list of pydantic errors, or object)
 *
 * Falls back to the provided `fallback` text.
 */
export function translateError(error, fallback = "Bir hata oluştu. Lütfen tekrar deneyin.") {
  if (!error) return fallback;

  // No response (CORS, DNS, offline)
  if (!error.response) {
    if (error.code === "ECONNABORTED") {
      return "Sunucu yanıt vermedi. Lütfen biraz sonra tekrar deneyin.";
    }
    return "Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.";
  }

  const { status, data } = error.response;
  const detail = data?.detail;

  // FastAPI validation errors (HTTPException with list of errors)
  if (Array.isArray(detail)) {
    const first = detail[0];
    if (first?.msg) return humanizeValidation(first);
  }

  // Plain string detail
  if (typeof detail === "string" && detail.trim()) {
    return translateBackendMessage(detail) || detail;
  }

  // Status-based fallbacks
  return statusFallback(status, fallback);
}

const STATUS_MESSAGES = {
  400: "Geçersiz istek. Bilgileri kontrol edip tekrar deneyin.",
  401: "Oturumunuz sona erdi. Lütfen tekrar giriş yapın.",
  403: "Bu işlem için yetkiniz yok.",
  404: "Aradığınız kayıt bulunamadı.",
  409: "Bu kayıt zaten mevcut.",
  422: "Gönderilen bilgilerde hata var. Lütfen alanları kontrol edin.",
  429: "Çok fazla istek gönderildi. Lütfen biraz bekleyin.",
  500: "Sunucuda bir hata oluştu. Lütfen daha sonra tekrar deneyin.",
  502: "Sunucuya ulaşılamıyor. Lütfen biraz sonra deneyin.",
  503: "Servis şu anda kullanılamıyor.",
};

function statusFallback(status, fallback) {
  return STATUS_MESSAGES[status] || fallback;
}

const BACKEND_PATTERNS = [
  [/invalid credentials/i, "E-posta veya şifre hatalı."],
  [/incorrect email or password/i, "E-posta veya şifre hatalı."],
  [/email already (registered|in use)/i, "Bu e-posta zaten kayıtlı."],
  [/user not found/i, "Kullanıcı bulunamadı."],
  [/area not found/i, "Alan bulunamadı."],
  [/scanner not found/i, "Tarayıcı bulunamadı."],
  [/invalid api key/i, "Geçersiz API anahtarı."],
  [/token (expired|invalid)/i, "Oturum süresi doldu. Lütfen tekrar giriş yapın."],
  [/refresh token/i, "Oturum yenilenemedi. Lütfen tekrar giriş yapın."],
  [/password.*(too short|at least)/i, "Şifre en az 8 karakter olmalı."],
  [/permission denied|not authorized/i, "Bu işlem için yetkiniz yok."],
  [/duplicate|already exists/i, "Bu kayıt zaten mevcut."],
];

function translateBackendMessage(msg) {
  for (const [pattern, replacement] of BACKEND_PATTERNS) {
    if (pattern.test(msg)) return replacement;
  }
  return null;
}

function humanizeValidation(item) {
  const field = Array.isArray(item.loc) ? item.loc[item.loc.length - 1] : null;
  const fieldLabel = field ? `“${prettifyField(field)}”` : "Form";

  const type = item.type || "";
  if (type.includes("missing")) return `${fieldLabel} alanı zorunludur.`;
  if (type.includes("email")) return `${fieldLabel} geçerli bir e-posta olmalı.`;
  if (type.includes("int")) return `${fieldLabel} sayısal olmalı.`;
  if (type.includes("float")) return `${fieldLabel} ondalık sayı olmalı.`;
  if (type.includes("min_length") || /at least/i.test(item.msg || "")) {
    return `${fieldLabel} çok kısa. Lütfen daha uzun bir değer girin.`;
  }
  if (type.includes("max_length")) {
    return `${fieldLabel} çok uzun.`;
  }
  if (type.includes("greater_than") || /greater than/i.test(item.msg || "")) {
    return `${fieldLabel} pozitif bir değer olmalı.`;
  }

  return `${fieldLabel}: ${item.msg}`;
}

const FIELD_LABELS = {
  email: "E-posta",
  password: "Şifre",
  name: "Ad",
  capacity: "Kapasite",
  floor: "Kat",
  latitude: "Enlem",
  longitude: "Boylam",
  area_id: "Alan",
  mac_hashes: "Cihaz listesi",
};

function prettifyField(field) {
  return FIELD_LABELS[field] || String(field).replace(/_/g, " ");
}
