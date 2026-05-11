const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000';
const WS_BASE  = import.meta.env.VITE_WS_URL  || 'ws://localhost:8000';

// ── REST helpers ────────────────────────────────────────────────

async function fetchJSON(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `HTTP ${res.status}`);
  }
  return res.json();
}

export const api = {
  getAreas: () => fetchJSON('/areas/'),

  getLiveOccupancy: () => fetchJSON('/occupancy/live'),

  getHistory: ({ areaId, days = 7 }) =>
    fetchJSON(`/occupancy/history?area_id=${areaId}&days=${days}`),

  subscribe: ({ fcmToken, areaId, thresholdPct, direction }) =>
    fetchJSON('/notifications/subscribe', {
      method: 'POST',
      body: JSON.stringify({
        fcm_token: fcmToken,
        area_id: areaId,
        threshold_pct: thresholdPct,
        direction,
      }),
    }),

  unsubscribe: (id) =>
    fetchJSON(`/notifications/subscribe/${id}`, { method: 'DELETE' }),

  getSubscriptions: (fcmToken) =>
    fetchJSON(`/notifications/subscriptions/${fcmToken}`),
};

// ── WebSocket hook ───────────────────────────────────────────────

import { useEffect, useRef, useState, useCallback } from 'react';

export function useWebSocket(onMessage) {
  const ws = useRef(null);
  const [connected, setConnected] = useState(false);
  const reconnectTimer = useRef(null);

  const connect = useCallback(() => {
    try {
      ws.current = new WebSocket(`${WS_BASE}/ws/live`);

      ws.current.onopen = () => {
        setConnected(true);
        console.log('🔌 WebSocket bağlandı');
      };

      ws.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          onMessage(data);
        } catch (e) {
          console.error('WS parse error:', e);
        }
      };

      ws.current.onclose = () => {
        setConnected(false);
        console.log('🔌 WebSocket bağlantısı kesildi. Yeniden bağlanılıyor...');
        reconnectTimer.current = setTimeout(connect, 3000);
      };

      ws.current.onerror = (e) => {
        console.error('WS error:', e);
        ws.current.close();
      };
    } catch (e) {
      console.error('WS connect error:', e);
      reconnectTimer.current = setTimeout(connect, 3000);
    }
  }, [onMessage]);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectTimer.current);
      ws.current?.close();
    };
  }, [connect]);

  return { connected };
}
