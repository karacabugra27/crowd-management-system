import { useEffect, useRef, useState } from "react";

const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);

function prefersReducedMotion() {
  if (typeof window === "undefined" || !window.matchMedia) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export default function useCountUp(target, { duration = 600, decimals = 0 } = {}) {
  const safeTarget = Number.isFinite(target) ? target : 0;
  const [value, setValue] = useState(safeTarget);
  const fromRef = useRef(safeTarget);
  const startTsRef = useRef(0);
  const rafRef = useRef(0);

  useEffect(() => {
    if (prefersReducedMotion() || duration <= 0) {
      fromRef.current = safeTarget;
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setValue((v) => (v === safeTarget ? v : safeTarget));
      return;
    }

    const from = fromRef.current;
    const delta = safeTarget - from;
    if (delta === 0) return;

    startTsRef.current = 0;
    const step = (ts) => {
      if (!startTsRef.current) startTsRef.current = ts;
      const elapsed = ts - startTsRef.current;
      const t = Math.min(1, elapsed / duration);
      const eased = easeOutCubic(t);
      const next = from + delta * eased;
      setValue(next);
      if (t < 1) {
        rafRef.current = requestAnimationFrame(step);
      } else {
        fromRef.current = safeTarget;
      }
    };
    rafRef.current = requestAnimationFrame(step);
    return () => cancelAnimationFrame(rafRef.current);
  }, [safeTarget, duration]);

  const factor = Math.pow(10, decimals);
  return Math.round(value * factor) / factor;
}
