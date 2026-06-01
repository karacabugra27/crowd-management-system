import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import PublicLayout from "./components/PublicLayout";
import AdminLayout from "./components/AdminLayout";
import DashboardPage from "./pages/DashboardPage";
import MapPage from "./pages/MapPage";
import AnalyticsPage from "./pages/AnalyticsPage";
import LoginPage from "./pages/LoginPage";
import AdminPage from "./pages/AdminPage";

function PageLoader() {
  return (
    <div className="page-loader">
      <div className="loader-spinner" />
    </div>
  );
}

function AdminProtectedRoute({ children }) {
  const { user, isAdmin, loading } = useAuth();
  if (loading) return <PageLoader />;
  if (!user) return <Navigate to="/admin/login" replace />;
  if (!isAdmin) return <Navigate to="/" replace />;
  return children;
}

function AdminPublicRoute({ children }) {
  const { user, isAdmin, loading } = useAuth();
  if (loading) return <PageLoader />;
  if (user && isAdmin) return <Navigate to="/admin" replace />;
  return children;
}

function AppRoutes() {
  return (
    <Routes>
      {/* Public user routes */}
      <Route element={<PublicLayout />}>
        <Route index element={<DashboardPage />} />
        <Route path="/map" element={<MapPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
      </Route>

      {/* Admin login (no layout) */}
      <Route
        path="/admin/login"
        element={
          <AdminPublicRoute>
            <LoginPage />
          </AdminPublicRoute>
        }
      />

      {/* Admin protected routes */}
      <Route
        path="/admin"
        element={
          <AdminProtectedRoute>
            <AdminLayout />
          </AdminProtectedRoute>
        }
      >
        <Route index element={<AdminPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
