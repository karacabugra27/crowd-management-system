import { useContext } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { CheckCircle2, AlertTriangle, Info, X } from "lucide-react";
import { ToastContext } from "../contexts/ToastContext";

const ICONS = {
  success: CheckCircle2,
  error: AlertTriangle,
  info: Info,
};

export default function Toaster() {
  const { toasts, dismissToast } = useContext(ToastContext);
  const reduceMotion = useReducedMotion();

  return (
    <div className="toast-stack" aria-live="polite" aria-atomic="false">
      <AnimatePresence initial={false}>
        {toasts.map((t) => {
          const Icon = ICONS[t.type] || Info;
          return (
            <motion.div
              key={t.id}
              role={t.type === "error" ? "alert" : "status"}
              className={`toast toast-${t.type}`}
              initial={reduceMotion ? false : { opacity: 0, x: 40, scale: 0.96 }}
              animate={{ opacity: 1, x: 0, scale: 1 }}
              exit={reduceMotion ? { opacity: 0 } : { opacity: 0, x: 40, scale: 0.96 }}
              transition={{ duration: 0.22, ease: [0.4, 0, 0.2, 1] }}
              layout={!reduceMotion}
            >
              <Icon size={18} className="toast-icon" />
              <div className="toast-body">
                {t.title && <strong>{t.title}</strong>}
                <span>{t.message}</span>
              </div>
              <button
                className="toast-close"
                onClick={() => dismissToast(t.id)}
                aria-label="Bildirimi kapat"
              >
                <X size={14} />
              </button>
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
