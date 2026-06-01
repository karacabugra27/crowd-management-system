import { motion, useReducedMotion } from "framer-motion";
import { Wifi, WifiOff } from "lucide-react";

/**
 * Animated WebSocket connection indicator.
 * - Connected: green pill with a soft pulsing dot.
 * - Disconnected: red pill, slightly smaller.
 * Color + scale interpolation runs at 600ms when the state flips.
 */
export default function WsStatusPill({ connected }) {
  const reduceMotion = useReducedMotion();
  const label = connected ? "Canlı bağlantı" : "Bağlantı kesildi";
  return (
    <motion.div
      className={`ws-status ${connected ? "connected" : "disconnected"}`}
      initial={false}
      animate={
        reduceMotion
          ? {}
          : { scale: connected ? 1 : 0.97 }
      }
      transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
      role="status"
      aria-live="polite"
    >
      {connected ? (
        <>
          <span className="ws-dot" aria-hidden="true" />
          <Wifi size={16} />
        </>
      ) : (
        <WifiOff size={16} />
      )}
      <span>{label}</span>
    </motion.div>
  );
}
