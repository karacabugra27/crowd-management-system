import { lazy, Suspense } from "react";
import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import PublicLayout from "./components/PublicLayout";
import AdminLayout from "./components/AdminLayout";
import DashboardPage from "./pages/DashboardPage";
import { DashboardSkeleton, AnalyticsSkeleton } from "./components/Skeleton";

// Lazy-loaded routes: split heavy deps (Leaflet, Recharts, admin tooling) out
// of the initial bundle so the public Dashboard boots faster.
const MapPage = lazy(() => import("./pages/MapPage"));
const AnalyticsPage = lazy(() => import("./pages/AnalyticsPage"));
const LoginPage = lazy(() => import("./pages/LoginPage"));
const AdminPage = lazy(() => import("./pages/AdminPage"));

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

function PageTransition({ children }) {
  const reduceMotion = useReducedMotion();
  if (reduceMotion) return <>{children}</>;
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -6 }}
      transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
    >
      {children}
    </motion.div>
  );
}

function AppRoutes() {
  const location = useLocation();
  return (
    <AnimatePresence mode="wait" initial={false}>
      <Routes location={location} key={location.pathname}>
        {/* Public user routes */}
        <Route element={<PublicLayout />}>
          <Route
            index
            element={
              <PageTransition>
                <DashboardPage />
              </PageTransition>
            }
          />
          <Route
            path="/map"
            element={
              <PageTransition>
                <Suspense fallback={<PageLoader />}>
                  <MapPage />
                </Suspense>
              </PageTransition>
            }
          />
          <Route
            path="/analytics"
            element={
              <PageTransition>
                <Suspense fallback={<AnalyticsSkeleton />}>
                  <AnalyticsPage />
                </Suspense>
              </PageTransition>
            }
          />
        </Route>

        {/* Admin login (no layout) */}
        <Route
          path="/admin/login"
          element={
            <AdminPublicRoute>
              <PageTransition>
                <Suspense fallback={<PageLoader />}>
                  <LoginPage />
                </Suspense>
              </PageTransition>
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
          <Route
            index
            element={
              <PageTransition>
                <Suspense fallback={<DashboardSkeleton />}>
                  <AdminPage />
                </Suspense>
              </PageTransition>
            }
          />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AnimatePresence>
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
