import React from 'react';

/**
 * Animated occupancy card for a single campus area.
 * Shows icon, name, percentage, progress bar, device count, capacity.
 */
export default function OccupancyCard({ data, onClick }) {
  const {
    area_name, short_name, building, icon,
    capacity, device_count, occupancy_pct,
    status, color, last_updated,
  } = data;

  const statusLabels = { green: 'Boş', yellow: 'Orta', orange: 'Dolu', red: 'Çok Dolu' };

  const formatTime = (ts) => {
    if (!ts) return '—';
    const d = new Date(ts);
    return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  };

  return (
    <div className="occupancy-card" onClick={() => onClick && onClick(data)}>
      {/* Card Header */}
      <div className="card-header">
        <div>
          <div className="card-icon">{icon}</div>
          <div className="card-title">{area_name}</div>
          <div className="card-subtitle">{building}</div>
        </div>
        <span className={`status-badge ${color}`}>
          <span>●</span>
          {statusLabels[color] || status}
        </span>
      </div>

      {/* Percentage */}
      <div className={`card-percentage ${color}`}>
        {occupancy_pct?.toFixed(0)}%
      </div>

      {/* Progress bar */}
      <div className="occupancy-bar-container" style={{ marginBottom: '0.75rem' }}>
        <div
          className={`occupancy-bar-fill ${color}`}
          style={{ width: `${Math.min(occupancy_pct, 100)}%` }}
        />
      </div>

      {/* Meta */}
      <div className="card-meta">
        <span>👥 {device_count} / {capacity} cihaz</span>
        <span>🕐 {formatTime(last_updated)}</span>
      </div>
    </div>
  );
}
