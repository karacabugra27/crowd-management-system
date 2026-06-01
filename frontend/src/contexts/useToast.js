import { useContext } from "react";
import { ToastContext } from "./ToastContext";

export function useToast() {
  const { showToast, dismissToast } = useContext(ToastContext);
  return {
    showToast,
    dismissToast,
    success: (message, opts = {}) => showToast({ type: "success", message, ...opts }),
    error: (message, opts = {}) => showToast({ type: "error", message, ...opts }),
    info: (message, opts = {}) => showToast({ type: "info", message, ...opts }),
  };
}
