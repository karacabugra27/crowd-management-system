import { Outlet, NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import {
  LayoutDashboard,
  Map,
  BarChart3,
  Shield,
  LogOut,
  User,
  Menu,
  X,
  Activity,
} from "lucide-react";
import { useState } from "react";

export default function Layout() {
  const { user, logout, isAdmin } = useAuth();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  const links = [
    { to: "/", icon: LayoutDashboard, label: "Dashboard" },
    { to: "/map", icon: Map, label: "Harita" },
    { to: "/analytics", icon: BarChart3, label: "Analitik" },
  ];

  if (isAdmin) {
    links.push({ to: "/admin", icon: Shield, label: "Yönetim" });
  }

  return (
    <div className="app-layout">
      {/* Mobile header */}
      <header className="mobile-header">
        <button
          className="menu-btn"
          onClick={() => setSidebarOpen(!sidebarOpen)}
          id="mobile-menu-toggle"
        >
          {sidebarOpen ? <X size={22} /> : <Menu size={22} />}
        </button>
        <div className="mobile-brand">
          <Activity size={20} className="brand-icon" />
          <span>CrowdPulse</span>
        </div>
      </header>

      {/* Sidebar */}
      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sidebar-brand">
          <Activity size={28} className="brand-icon" />
          <div>
            <h1>CrowdPulse</h1>
            <span className="brand-sub">Kampüs Yönetimi</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === "/"}
              className={({ isActive }) =>
                `nav-link ${isActive ? "active" : ""}`
              }
              onClick={() => setSidebarOpen(false)}
              id={`nav-${link.label.toLowerCase()}`}
            >
              <link.icon size={20} />
              <span>{link.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">
              <User size={18} />
            </div>
            <div className="user-details">
              <span className="user-email">{user?.email}</span>
              <span className="user-role">
                {user?.role === "admin" ? "Yönetici" : "Kullanıcı"}
              </span>
            </div>
          </div>
          <button
            className="logout-btn"
            onClick={handleLogout}
            id="logout-button"
          >
            <LogOut size={18} />
            <span>Çıkış</span>
          </button>
        </div>
      </aside>

      {/* Overlay for mobile */}
      {sidebarOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main content */}
      <main className="main-content">
        <Outlet />
      </main>
    </div>
  );
}
