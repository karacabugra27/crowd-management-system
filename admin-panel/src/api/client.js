export const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ||
  'http://localhost:8000'
).replace(/\/$/, '');

export function getToken() {
  return localStorage.getItem(
    'access_token'
  );
}

export function setToken(token) {
  localStorage.setItem(
    'access_token',
    token
  );
}

export function clearToken() {
  localStorage.removeItem(
    'access_token'
  );
}

function buildUrl(path) {
  if (path.startsWith('http')) {
    return path;
  }

  return `${API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
}

function getReadableError(payload, status) {
  if (!payload) {
    return `HTTP ${status}`;
  }

  if (typeof payload === 'string') {
    return payload;
  }

  if (typeof payload.detail === 'string') {
    return payload.detail;
  }

  if (Array.isArray(payload.detail)) {
    return payload.detail
      .map((item) => item.msg || item.message || JSON.stringify(item))
      .join(', ');
  }

  return payload.message || payload.error || `HTTP ${status}`;
}

export async function apiRequest(
  path,
  options = {}
) {
  const {
    auth = true,
    headers: optionHeaders = {},
    ...fetchOptions
  } = options;
  const token = getToken();

  const headers = {
    ...optionHeaders,
  };

  if (fetchOptions.body && !(fetchOptions.body instanceof FormData)) {
    headers['Content-Type'] = headers['Content-Type'] || 'application/json';
  }

  if (auth && token) {
    headers.Authorization = `Bearer ${token}`;
  }

  let response;

  try {
    response = await fetch(buildUrl(path), {
      ...fetchOptions,
      headers,
    });
  } catch {
    throw new Error(
      `Backend'e bağlanılamadı (${API_BASE_URL}). Sunucunun çalıştığını kontrol edin.`
    );
  }

  const text = await response.text();
  let payload = null;

  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }

  if (!response.ok) {
    const message = getReadableError(payload, response.status);
    const error = new Error(message);
    error.status = response.status;

    throw error;
  }

  return payload;
}
