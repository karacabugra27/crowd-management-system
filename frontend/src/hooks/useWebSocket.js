import { useEffect, useRef, useCallback, useState } from "react";
import { getWsUrl } from "../api/client";

/**
 * Custom hook for real-time occupancy WebSocket.
 * @param {number|null} areaId – subscribe to one area, or null for all
 * @param {function} onMessage – callback receiving parsed JSON messages
 * @param {object}   [opts]
 * @param {number}   [opts.throttleMs=0] – per-area trailing throttle in ms.
 *   When >0, messages for the same `area_id` arriving within the window are
 *   coalesced; only the latest is emitted, with a leading-edge emit. This
 *   prevents quick-fire updates from breaking the 600ms ring animation.
 */
export default function useWebSocket(areaId = null, onMessage, opts = {}) {
  const { throttleMs = 0 } = opts;
  const wsRef = useRef(null);
  const [connected, setConnected] = useState(false);
  const reconnectTimer = useRef(null);
  const onMessageRef = useRef(onMessage);
  const lastEmitAtRef = useRef(new Map());
  const pendingRef = useRef(new Map());

  // Keep latest callback without forcing reconnect when it changes.
  useEffect(() => {
    onMessageRef.current = onMessage;
  }, [onMessage]);

  const dispatch = useCallback(
    (data) => {
      const emit = (d) => onMessageRef.current?.(d);
      if (throttleMs <= 0 || data?.area_id == null) {
        emit(data);
        return;
      }
      const aid = data.area_id;
      const now = Date.now();
      const last = lastEmitAtRef.current.get(aid) || 0;
      const elapsed = now - last;
      if (elapsed >= throttleMs) {
        lastEmitAtRef.current.set(aid, now);
        const pending = pendingRef.current.get(aid);
        if (pending) {
          clearTimeout(pending.timer);
          pendingRef.current.delete(aid);
        }
        emit(data);
        return;
      }
      const wait = throttleMs - elapsed;
      const existing = pendingRef.current.get(aid);
      if (existing) clearTimeout(existing.timer);
      const timer = setTimeout(() => {
        const latest = pendingRef.current.get(aid)?.latestMsg;
        pendingRef.current.delete(aid);
        lastEmitAtRef.current.set(aid, Date.now());
        if (latest) emit(latest);
      }, wait);
      pendingRef.current.set(aid, { timer, latestMsg: data });
    },
    [throttleMs]
  );

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const url = getWsUrl(areaId);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => setConnected(true);

    ws.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        dispatch(data);
      } catch { /* ignore non-JSON frames */ }
    };

    ws.onclose = () => {
      setConnected(false);
      reconnectTimer.current = setTimeout(connect, 3000);
    };

    ws.onerror = () => ws.close();
  }, [areaId, dispatch]);

  useEffect(() => {
    connect();
    const pending = pendingRef.current;
    return () => {
      clearTimeout(reconnectTimer.current);
      pending.forEach((p) => clearTimeout(p.timer));
      pending.clear();
      const ws = wsRef.current;
      if (ws) {
        // Strip the reconnect handler so unmount doesn't queue a fresh socket.
        ws.onclose = null;
        ws.onerror = null;
        ws.close();
      }
    };
  }, [connect]);

  return { connected };
}
