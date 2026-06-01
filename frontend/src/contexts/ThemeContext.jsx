/* eslint-disable react-refresh/only-export-components */
import { createContext, useEffect, useState, useCallback } from "react";

const STORAGE_KEY = "crowdly-theme";

export const ThemeContext = createContext({
  theme: "system",
  resolved: "dark",
  setTheme: () => {},
  toggle: () => {},
});

function readStored() {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    return v === "light" || v === "dark" ? v : "system";
  } catch {
    return "system";
  }
}

function systemPref() {
  if (typeof window === "undefined" || !window.matchMedia) return "dark";
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function applyTheme(theme) {
  const root = document.documentElement;
  if (theme === "light" || theme === "dark") {
    root.setAttribute("data-theme", theme);
  } else {
    root.removeAttribute("data-theme");
  }
}

export function ThemeProvider({ children }) {
  const [theme, setThemeState] = useState(readStored);
  const [resolved, setResolved] = useState(() =>
    theme === "system" ? systemPref() : theme
  );

  const setTheme = useCallback((next) => {
    setThemeState(next);
    try {
      if (next === "system") localStorage.removeItem(STORAGE_KEY);
      else localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* ignore */
    }
    applyTheme(next);
    setResolved(next === "system" ? systemPref() : next);
  }, []);

  const toggle = useCallback(() => {
    setTheme(resolved === "light" ? "dark" : "light");
  }, [resolved, setTheme]);

  // React to system preference changes when theme === "system"
  useEffect(() => {
    if (theme !== "system" || !window.matchMedia) return;
    const mq = window.matchMedia("(prefers-color-scheme: light)");
    const onChange = (e) => setResolved(e.matches ? "light" : "dark");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, resolved, setTheme, toggle }}>
      {children}
    </ThemeContext.Provider>
  );
}
