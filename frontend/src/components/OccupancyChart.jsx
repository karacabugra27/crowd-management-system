import React, { useState, useEffect } from 'react';
import {
  LineChart, Line, AreaChart, Area,
  XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, ReferenceLine,
} from 'recharts';
import { api } from '../services/api';

const COLOR_MAP = {
  green:  '#10b981',
  yellow: '#f59e0b',
  orange: '#f97316',
  red:    '#ef4444',
  blue:   '#3b82f6',
};

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  const d = payload[0];
  const pct = d?.value;
  const color = pct < 30 ? 'green' : pct < 60 ? 'yellow' : pct < 85 ? 'orange' : 'red';
  return (
    <div style={{
      background: 'var(--bg-card)',
      border: '1px solid var(--border-subtle)',
      borderRadius: '10px',
      padding: '0.75rem 1rem',
      fontSize: '0.8rem',
    }}>
      <div style={{ color: 'var(--text-muted)', marginBottom: '0.35rem' }}>{label}</div>
      <div style={{ fontWeight: 700, fontSize: '1.1rem', color: COLOR_MAP[color] }}>
        %{pct?.toFixed(1)}
      </div>
      {payload[1] && (
        <div style={{ color: 'var(--text-secondary)' }}>
          {payload[1].value} cihaz
        </div>
      )}
    </div>
  );
}

export default function OccupancyChart({ areas }) {
  const [selectedArea, setSelectedArea]  = useState(null);
  const [days, setDays]                  = useState(1);
  const [chartData, setChartData]        = useState([]);
  const [isLoading, setIsLoading]        = useState(false);

  // Select first area by default
  useEffect(() => {
    if (areas?.length && !selectedArea) setSelectedArea(areas[0]);
  }, [areas]);

  useEffect(() => {
    if (!selectedArea) return;
    setIsLoading(true);
    api.getHistory({ areaId: selectedArea.area_id || selectedArea.id, days })
      .then((records) => {
        const formatted = records.map((r) => ({
          time: new Date(r.timestamp).toLocaleString('tr-TR', {
            day: '2-digit', month: '2-digit',
            hour: '2-digit', minute: '2-digit',
          }),
          pct: r.occupancy_pct,
          devices: r.device_count,
        }));
        setChartData(formatted);
      })
      .catch(console.error)
      .finally(() => setIsLoading(false));
  }, [selectedArea, days]);

  const DAY_OPTIONS = [
    { value: 1, label: 'Bugün' },
    { value: 3, label: '3 Gün' },
    { value: 7, label: '7 Gün' },
  ];

  return (
    <div className="chart-wrapper">
      {/* Controls */}
      <div className="section-header">
        <h3 className="section-title">📈 Tarihsel Doluluk Analizi</h3>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          {/* Day selector */}
          <div className="filter-tabs">
            {DAY_OPTIONS.map(o => (
              <button
                key={o.value}
                className={`filter-tab ${days === o.value ? 'active' : ''}`}
                onClick={() => setDays(o.value)}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Area selector */}
      {areas?.length > 0 && (
        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginBottom: '1.5rem' }}>
          {areas.map((a) => (
            <button
              key={a.area_id || a.id}
              className={`filter-tab ${selectedArea?.area_id === a.area_id || selectedArea?.id === a.id ? 'active' : ''}`}
              onClick={() => setSelectedArea(a)}
            >
              {a.icon} {a.short_name || a.area_name}
            </button>
          ))}
        </div>
      )}

      {/* Chart */}
      {isLoading ? (
        <div className="loading-container" style={{ padding: '3rem' }}>
          <div className="spinner" />
          <span>Geçmiş veriler yükleniyor...</span>
        </div>
      ) : chartData.length === 0 ? (
        <div className="loading-container" style={{ padding: '3rem' }}>
          <span style={{ fontSize: '2rem' }}>📊</span>
          <span>Henüz veri yok. Kolektör çalışmaya başladıktan sonra veri görünecek.</span>
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={320}>
          <AreaChart data={chartData} margin={{ top: 10, right: 10, bottom: 0, left: -10 }}>
            <defs>
              <linearGradient id="pctGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%"  stopColor="#3b82f6" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis
              dataKey="time"
              tick={{ fill: '#4a6080', fontSize: 11 }}
              tickLine={false}
              axisLine={false}
              interval="preserveStartEnd"
            />
            <YAxis
              tick={{ fill: '#4a6080', fontSize: 11 }}
              tickLine={false}
              axisLine={false}
              domain={[0, 100]}
              tickFormatter={(v) => `${v}%`}
            />
            <Tooltip content={<CustomTooltip />} />
            <ReferenceLine y={80} stroke="#ef4444" strokeDasharray="4 2" strokeOpacity={0.5}
              label={{ value: '%80 Kritik', position: 'right', fill: '#ef4444', fontSize: 10 }} />
            <ReferenceLine y={60} stroke="#f59e0b" strokeDasharray="4 2" strokeOpacity={0.4}
              label={{ value: '%60', position: 'right', fill: '#f59e0b', fontSize: 10 }} />
            <Area
              type="monotone"
              dataKey="pct"
              stroke="#3b82f6"
              strokeWidth={2}
              fill="url(#pctGradient)"
              dot={false}
              activeDot={{ r: 5, fill: '#3b82f6', stroke: '#1e3a5f', strokeWidth: 2 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}
