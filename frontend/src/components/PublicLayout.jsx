import { Outlet, NavLink, Link } from "react-router-dom";
import { LayoutDashboard, Map, BarChart3, Activity, Shield, Menu, X } from "lucide-react";
import { useState } from "react";

export default function PublicLayout() {
  const [menuOpen, setMenuOpen] = useState(false);

  const links = [
    { to: "/", icon: LayoutDashboard, label: "Genel Bakış", end: true },
    { to: "/map", icon: Map, label: "Harita" },
    { to: "/analytics", icon: BarChart3, label: "Analitik" },
  ];

  return (
    <div className="public-layout">
      <header className="public-header">
        <div className="public-header-inner">
          <Link to="/" className="public-brand" onClick={() => setMenuOpen(false)}>
            <Activity size={26} className="brand-icon" />
            <div className="brand-text">
              <strong>Crowdly</strong>
              <span>Kampüs Yoğunluk Takibi</span>
            </div>
          </Link>

          <nav className={`public-nav ${menuOpen ? "open" : ""}`}>
            {links.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                end={link.end}
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  `public-nav-link ${isActive ? "active" : ""}`
                }
              >
                <link.icon size={18} />
                <span>{link.label}</span>
              </NavLink>
            ))}
            <Link
              to="/admin/login"
              className="public-admin-link"
              onClick={() => setMenuOpen(false)}
            >
              <Shield size={16} />
              <span>Yönetici Girişi</span>
            </Link>
          </nav>

          <button
            className="public-menu-btn"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label="Menüyü aç"
          >
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </header>

      <main className="public-main">
        <Outlet />
      </main>

      <footer className="public-footer">
        <span>© {new Date().getFullYear()} Crowdly</span>
        <span className="public-footer-sep">·</span>
        <span>Akıllı Kampüs Kalabalık Yönetim Sistemi</span>
      </footer>
    </div>
  );
}
