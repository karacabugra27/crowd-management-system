/* eslint-disable react-refresh/only-export-components */
import { createContext, useCallback, useRef, useState } from "react";

export const ToastContext = createContext({
  toasts: [],
  showToast: () => {},
  dismissToast: () => {},
});

let toastIdCounter = 0;

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const timers = useRef(new Map());

  const dismissToast = useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    const t = timers.current.get(id);
    if (t) {
      clearTimeout(t);
      timers.current.delete(id);
    }
  }, []);

  const showToast = useCallback(
    ({ type = "info", title, message, duration = 4000 } = {}) => {
      const id = ++toastIdCounter;
      setToasts((prev) => [...prev, { id, type, title, message }]);
      if (duration > 0) {
        const handle = setTimeout(() => dismissToast(id), duration);
        timers.current.set(id, handle);
      }
      return id;
    },
    [dismissToast]
  );

  return (
    <ToastContext.Provider value={{ toasts, showToast, dismissToast }}>
      {children}
    </ToastContext.Provider>
  );
}
