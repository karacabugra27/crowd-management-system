import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from 'react-leaflet';

const COLOR_MAP = {
  green:  { fill: '#10b981', opacity: 0.7 },
  yellow: { fill: '#f59e0b', opacity: 0.7 },
  orange: { fill: '#f97316', opacity: 0.75 },
  red:    { fill: '#ef4444', opacity: 0.8 },
};

// Campus center (Inönü University)
const CAMPUS_CENTER = [38.3308, 38.4357];

function MapBoundsUpdater({ areas }) {
  const map = useMap();
  useEffect(() => {
    if (areas?.length) {
      const validAreas = areas.filter(a => a.lat && a.lng);
      if (validAreas.length > 0) {
        const bounds = validAreas.map(a => [a.lat, a.lng]);
        map.fitBounds(bounds, { padding: [40, 40] });
      }
    }
  }, [areas, map]);
  return null;
}

export default function HeatMap({ occupancyData }) {
  const areas = occupancyData?.filter(a => a.lat && a.lng) || [];

  return (
    <div>
      <div className="section-header" style={{ marginBottom: '1rem' }}>
        <h3 className="section-title">🗺️ Kampüs Yoğunluk Haritası</h3>
        <div style={{ display: 'flex', gap: '1rem', fontSize: '0.75rem', color: 'var(--text-muted)', alignItems: 'center' }}>
          {[
            { color: '#10b981', label: 'Boş' },
            { color: '#f59e0b', label: 'Orta' },
            { color: '#f97316', label: 'Dolu' },
            { color: '#ef4444', label: 'Çok Dolu' },
          ].map(l => (
            <span key={l.label} style={{ display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
              <span style={{ width: 10, height: 10, borderRadius: '50%', background: l.color, display: 'inline-block' }} />
              {l.label}
            </span>
          ))}
        </div>
      </div>

      <div className="map-container">
        <MapContainer
          center={CAMPUS_CENTER}
          zoom={17}
          style={{ width: '100%', height: '100%' }}
          zoomControl={true}
        >
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            attribution='&copy; <a href="https://carto.com/">CARTO</a>'
          />
          <MapBoundsUpdater areas={areas} />
          {areas.map((area) => {
            const colorConfig = COLOR_MAP[area.color] || COLOR_MAP.green;
            const radius = 20 + (area.occupancy_pct / 100) * 30; // dynamic radius

            return (
              <CircleMarker
                key={area.area_id}
                center={[area.lat, area.lng]}
                radius={radius}
                pathOptions={{
                  fillColor: colorConfig.fill,
                  fillOpacity: colorConfig.opacity,
                  color: colorConfig.fill,
                  weight: 2,
                  opacity: 0.9,
                }}
              >
                <Popup>
                  <div style={{ fontFamily: 'Inter, sans-serif', minWidth: '180px' }}>
                    <div style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: '0.5rem' }}>
                      {area.icon} {area.area_name}
                    </div>
                    <div style={{ color: colorConfig.fill, fontSize: '1.4rem', fontWeight: 900 }}>
                      %{area.occupancy_pct?.toFixed(0)}
                    </div>
                    <div style={{ fontSize: '0.8rem', color: '#888', marginTop: '0.25rem' }}>
                      {area.device_count} / {area.capacity} cihaz
                    </div>
                    <div style={{ fontSize: '0.75rem', color: '#888', marginTop: '0.25rem' }}>
                      📍 {area.building}
                    </div>
                  </div>
                </Popup>
              </CircleMarker>
            );
          })}
        </MapContainer>
      </div>

      {areas.length === 0 && (
        <div className="loading-container" style={{ marginTop: '1rem' }}>
          <span>📡 Harita verisi bekleniyor... (Alanların koordinat bilgisi gerekli)</span>
        </div>
      )}
    </div>
  );
}
