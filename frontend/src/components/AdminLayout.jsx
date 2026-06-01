import { Outlet, NavLink, Link, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import {
  LayoutDashboard,
  Shield,
  LogOut,
  User,
  Menu,
  X,
  Activity,
  ExternalLink,
} from "lucide-react";
import { useState } from "react";

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate("/admin/login");
  };

  const links = [{ to: "/admin", icon: LayoutDashboard, label: "Yönetim Paneli", end: true }];

  return (
    <div className="app-layout">
      <header className="mobile-header">
        <button
          className="menu-btn"
          onClick={() => setSidebarOpen(!sidebarOpen)}
          aria-label="Menüyü aç"
        >
          {sidebarOpen ? <X size={22} /> : <Menu size={22} />}
        </button>
        <div className="mobile-brand">
          <Shield size={20} className="brand-icon" />
          <span>Crowdly · Yönetim</span>
        </div>
      </header>

      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sidebar-brand">
          <Activity size={28} className="brand-icon" />
          <div>
            <h1>Crowdly</h1>
            <span className="brand-sub">Yönetim Paneli</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.end}
              className={({ isActive }) =>
                `nav-link ${isActive ? "active" : ""}`
              }
              onClick={() => setSidebarOpen(false)}
            >
              <link.icon size={20} />
              <span>{link.label}</span>
            </NavLink>
          ))}

          <Link
            to="/"
            className="nav-link nav-link-external"
            onClick={() => setSidebarOpen(false)}
          >
            <ExternalLink size={18} />
            <span>Kullanıcı Sayfasına Dön</span>
          </Link>
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">
              <User size={18} />
            </div>
            <div className="user-details">
              <span className="user-email">{user?.email}</span>
              <span className="user-role">Yönetici</span>
            </div>
          </div>
          <button className="logout-btn" onClick={handleLogout}>
            <LogOut size={18} />
            <span>Çıkış</span>
          </button>
        </div>
      </aside>

      {sidebarOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <main className="main-content">
        <Outlet />
      </main>
    </div>
  );
}
