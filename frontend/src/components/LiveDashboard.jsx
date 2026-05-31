import React, { useState, useCallback, useEffect } from 'react';
import { useWebSocket, api } from '../services/api';
import OccupancyCard from './OccupancyCard';

const STATUS_COLORS = { green: '#10b981', yellow: '#f59e0b', orange: '#f97316', red: '#ef4444' };

export default function LiveDashboard({ onAreaClick }) {
  const [occupancyData, setOccupancyData] = useState([]);
  const [lastUpdate, setLastUpdate]       = useState(null);
  const [filter, setFilter]               = useState('all');
  const [isLoading, setIsLoading]         = useState(true);
  const [secondsAgo, setSecondsAgo]       = useState(0);

  // Handle WebSocket messages
  const handleMessage = useCallback((msg) => {
    if (msg.type === 'occupancy_update' && msg.data) {
      setOccupancyData(msg.data);
      setLastUpdate(new Date());
      setSecondsAgo(0);
      setIsLoading(false);
    }
  }, []);

  const { connected } = useWebSocket(handleMessage);

  // Fallback: poll REST if WS not connected
  useEffect(() => {
    if (!connected) {
      api.getLiveOccupancy()
        .then((data) => { setOccupancyData(data); setIsLoading(false); })
        .catch(console.error);
    }
  }, [connected]);

  // Update "seconds ago" counter
  useEffect(() => {
    const t = setInterval(() => setSecondsAgo((s) => s + 1), 1000);
    return () => clearInterval(t);
  }, []);

  // Summary stats
  const stats = {
    total: occupancyData.length,
    empty:  occupancyData.filter(a => a.color === 'green').length,
    medium: occupancyData.filter(a => a.color === 'yellow').length,
    full:   occupancyData.filter(a => a.color === 'orange' || a.color === 'red').length,
    avgPct: occupancyData.length
      ? (occupancyData.reduce((s, a) => s + a.occupancy_pct, 0) / occupancyData.length).toFixed(0)
      : 0,
  };

  // Filter
  const filtered = filter === 'all'
    ? occupancyData
    : occupancyData.filter(a =>
        filter === 'empty'  ? a.color === 'green' :
        filter === 'medium' ? a.color === 'yellow' :
        filter === 'full'   ? (a.color === 'orange' || a.color === 'red') : true
      );

  const FILTERS = [
    { key: 'all',    label: 'Tümü' },
    { key: 'empty',  label: '🟢 Boş' },
    { key: 'medium', label: '🟡 Orta' },
    { key: 'full',   label: '🔴 Dolu' },
  ];

  return (
    <div className="page-container">
      {/* Header */}
      <div className="page-header" style={{ padding: 0, marginBottom: '1.75rem' }}>
        <div className="page-header-info">
          <h1>Canlı Doluluk Durumu</h1>
          <p>Tüm kampüs alanları • Gerçek zamanlı güncelleme</p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          {connected ? (
            <span className="live-badge">
              <span className="live-dot" />
              CANLI
            </span>
          ) : (
            <span className="status-badge red">⚠ Bağlantı Kesildi</span>
          )}
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            {lastUpdate ? `${secondsAgo}s önce güncellendi` : 'Bağlanıyor...'}
          </span>
        </div>
      </div>

      {/* Summary stats */}
      <div className="stats-row">
        <div className="stat-card">
          <span className="stat-label">Ortalama Doluluk</span>
          <span className="stat-value">{stats.avgPct}%</span>
          <span className="stat-sub">Tüm alanlar</span>
        </div>
        <div className="stat-card">
          <span className="stat-label">Boş Alanlar</span>
          <span className="stat-value" style={{ color: 'var(--status-green)' }}>{stats.empty}</span>
          <span className="stat-sub">%30'dan az dolu</span>
        </div>
        <div className="stat-card">
          <span className="stat-label">Orta Yoğunluk</span>
          <span className="stat-value" style={{ color: 'var(--status-yellow)' }}>{stats.medium}</span>
          <span className="stat-sub">%30–60 arası</span>
        </div>
        <div className="stat-card">
          <span className="stat-label">Dolu / Çok Dolu</span>
          <span className="stat-value" style={{ color: 'var(--status-red)' }}>{stats.full}</span>
          <span className="stat-sub">%60'tan fazla</span>
        </div>
        <div className="stat-card">
          <span className="stat-label">Toplam Alan</span>
          <span className="stat-value">{stats.total}</span>
          <span className="stat-sub">İzlenen</span>
        </div>
      </div>

      {/* Filter tabs */}
      <div className="section-header">
        <div className="filter-tabs">
          {FILTERS.map(f => (
            <button
              key={f.key}
              className={`filter-tab ${filter === f.key ? 'active' : ''}`}
              onClick={() => setFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
          {filtered.length} alan gösteriliyor
        </span>
      </div>

      {/* Cards */}
      {isLoading ? (
        <div className="loading-container">
          <div className="spinner" />
          <span>Veriler yükleniyor...</span>
        </div>
      ) : filtered.length === 0 ? (
        <div className="loading-container">
          <span style={{ fontSize: '2rem' }}>🔍</span>
          <span>Bu filtreye uygun alan bulunamadı</span>
        </div>
      ) : (
        <div className="cards-grid">
          {filtered.map((area) => (
            <OccupancyCard
              key={area.area_id}
              data={area}
              onClick={onAreaClick}
            />
          ))}
        </div>
      )}
    </div>
  );
}
