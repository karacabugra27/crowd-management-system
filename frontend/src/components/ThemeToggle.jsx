import { Sun, Moon } from "lucide-react";
import { useTheme } from "../contexts/useTheme";

export default function ThemeToggle() {
  const { resolved, toggle } = useTheme();
  const isLight = resolved === "light";
  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={toggle}
      aria-label={isLight ? "Koyu temaya geç" : "Açık temaya geç"}
      title={isLight ? "Koyu tema" : "Açık tema"}
    >
      {isLight ? <Moon size={18} /> : <Sun size={18} />}
    </button>
  );
}
