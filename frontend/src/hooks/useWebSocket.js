import { useEffect, useRef, useCallback, useState } from "react";
import { getWsUrl } from "../api/client";

/**
 * Custom hook for real-time occupancy WebSocket.
 * @param {number|null} areaId – subscribe to one area, or null for all
 * @param {function} onMessage – callback receiving parsed JSON messages
 */
export default function useWebSocket(areaId = null, onMessage) {
  const wsRef = useRef(null);
  const [connected, setConnected] = useState(false);
  const reconnectTimer = useRef(null);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const url = getWsUrl(areaId);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => setConnected(true);

    ws.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        onMessage?.(data);
      } catch { /* ignore non-JSON frames */ }
    };

    ws.onclose = () => {
      setConnected(false);
      reconnectTimer.current = setTimeout(connect, 3000);
    };

    ws.onerror = () => ws.close();
  }, [areaId, onMessage]);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectTimer.current);
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
