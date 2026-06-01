import { useEffect, useRef } from "react";
import { useToast } from "../contexts/useToast";

/**
 * Fires a toast when the WebSocket transitions between connected/disconnected.
 * Skips the first render so the initial "disconnected" state on mount doesn't
 * spam users with a notification before the socket has had a chance to open.
 */
export default function useWsToast(connected) {
  const toast = useToast();
  const prevConnected = useRef(connected);
  const initial = useRef(true);

  useEffect(() => {
    if (initial.current) {
      initial.current = false;
      prevConnected.current = connected;
      return;
    }
    if (connected === prevConnected.current) return;
    prevConnected.current = connected;
    if (connected) {
      toast.success("Canlı bağlantı kuruldu.", { duration: 2500 });
    } else {
      toast.error("Canlı bağlantı kesildi. Yeniden bağlanılıyor…", {
        duration: 3500,
      });
    }
  }, [connected, toast]);
}
