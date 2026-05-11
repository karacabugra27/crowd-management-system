import React, { useState, useEffect, useCallback } from 'react';
import LiveDashboard from './components/LiveDashboard';
import OccupancyChart from './components/OccupancyChart';
import HeatMap from './components/HeatMap';
import NotificationPanel from './components/NotificationPanel';
import { api, useWebSocket } from './services/api';
import './index.css';

const NAV_ITEMS = [
  { key: 'dashboard',      icon: '📡', label: 'Canlı Dashboard' },
  { key: 'history',        icon: '📈', label: 'Tarihsel Analiz' },
  { key: 'map',            icon: '🗺️', label: 'Yoğunluk Haritası' },
  { key: 'notifications',  icon: '🔔', label: 'Bildirimler' },
];

function Sidebar({ activePage, onNavigate }) {
  return (
    <nav className="sidebar">
      {/* Logo */}
      <div className="sidebar-logo">
        <span className="sidebar-logo-icon">🏫</span>
        <div className="sidebar-logo-text">
          <h2>CampusPulse</h2>
          <span>Kalabalık Yönetimi</span>
        </div>
      </div>

      {/* Nav items */}
      {NAV_ITEMS.map(item => (
        <button
          key={item.key}
          id={`nav-${item.key}`}
          className={`sidebar-nav-item ${activePage === item.key ? 'active' : ''}`}
          onClick={() => onNavigate(item.key)}
        >
          <span className="nav-icon">{item.icon}</span>
          <span>{item.label}</span>
        </button>
      ))}

      {/* Footer */}
      <div className="sidebar-footer">
        <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', lineHeight: 1.6 }}>
          <div style={{ fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.35rem' }}>
            Kablosuz & Mobil Ağlar
          </div>
          Akıllı Kampüs Kalabalık Yönetim Sistemi
        </div>
      </div>
    </nav>
  );
}

export default function App() {
  const [activePage, setActivePage] = useState('dashboard');
  const [areas, setAreas]           = useState([]);
  const [liveData, setLiveData]     = useState([]);

  // Fetch areas once on mount
  useEffect(() => {
    api.getAreas()
      .then(setAreas)
      .catch(console.error);
  }, []);

  // Keep live data in sync for map and chart
  const handleWsMessage = useCallback((msg) => {
    if (msg.type === 'occupancy_update') setLiveData(msg.data);
  }, []);

  useWebSocket(handleWsMessage);

  // Merge area coords into live data
  const enrichedLiveData = liveData.map(item => {
    const area = areas.find(a => a.id === item.area_id);
    return area ? { ...item, lat: area.lat, lng: area.lng } : item;
  });

  return (
    <div className="app-layout">
      <Sidebar activePage={activePage} onNavigate={setActivePage} />

      <main className="main-content">
        {activePage === 'dashboard' && (
          <LiveDashboard onAreaClick={(area) => {
            setActivePage('history');
          }} />
        )}

        {activePage === 'history' && (
          <div className="page-container">
            <div className="page-header" style={{ padding: 0, marginBottom: '1.75rem' }}>
              <div className="page-header-info">
                <h1>Tarihsel Analiz</h1>
                <p>Alan bazlı doluluk geçmişi ve trend analizi</p>
              </div>
            </div>
            <OccupancyChart areas={enrichedLiveData.length ? enrichedLiveData : areas.map(a => ({
              area_id: a.id, area_name: a.name, short_name: a.short_name, icon: a.icon,
            }))} />
          </div>
        )}

        {activePage === 'map' && (
          <div className="page-container">
            <div className="page-header" style={{ padding: 0, marginBottom: '1.75rem' }}>
              <div className="page-header-info">
                <h1>Yoğunluk Haritası</h1>
                <p>Kampüs genelinde gerçek zamanlı doluluk dağılımı</p>
              </div>
            </div>
            <HeatMap occupancyData={enrichedLiveData} />
          </div>
        )}

        {activePage === 'notifications' && (
          <NotificationPanel areas={enrichedLiveData.length ? enrichedLiveData : areas.map(a => ({
            ...a, area_id: a.id, area_name: a.name,
          }))} />
        )}
      </main>
    </div>
  );
}
