import { createContext, useContext, useState, useEffect, useCallback } from "react";
import {
  authApi,
  usersApi,
  setTokens,
  clearTokens,
  getAccessToken,
} from "../api/client";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchUser = useCallback(async () => {
    try {
      const { data } = await usersApi.me();
      setUser(data);
    } catch {
      setUser(null);
      clearTokens();
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (getAccessToken()) {
      fetchUser();
    } else {
      setLoading(false);
    }
  }, [fetchUser]);

  const login = async (email, password) => {
    const { data } = await authApi.login(email, password);
    setTokens(data.access_token, data.refresh_token);
    await fetchUser();
  };

  const register = async (email, password) => {
    const { data } = await authApi.register(email, password);
    setTokens(data.access_token, data.refresh_token);
    await fetchUser();
  };

  const logout = () => {
    clearTokens();
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{ user, loading, login, register, logout, isAdmin: user?.role === "admin" }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be inside AuthProvider");
  return ctx;
}
