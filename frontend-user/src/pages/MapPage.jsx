import { useState, useEffect, useCallback, useRef } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import { occupancyApi, areasApi } from "../api/client";
import useWebSocket from "../hooks/useWebSocket";
import {
  statusColor,
  statusLabel,
  statusBg,
  formatPercent,
} from "../utils/helpers";
import { Wifi, WifiOff, Layers, Navigation } from "lucide-react";

/* ─── Custom marker icon factory ────────────────────────── */
function createIcon(status, pct) {
  const color = statusColor(status);
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="48" height="56" viewBox="0 0 48 56">
      <defs>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.3"/>
        </filter>
      </defs>
      <path d="M24 54 C24 54 4 32 4 20 C4 9 13 0 24 0 C35 0 44 9 44 20 C44 32 24 54 24 54Z"
            fill="${color}" filter="url(#shadow)" opacity="0.9"/>
      <circle cx="24" cy="20" r="14" fill="white" opacity="0.95"/>
      <text x="24" y="25" text-anchor="middle" font-size="12" font-weight="700"
            fill="${color}" font-family="Inter,sans-serif">${Math.round(pct)}%</text>
    </svg>`;
  return L.divIcon({
    html: svg,
    iconSize: [48, 56],
    iconAnchor: [24, 56],
    popupAnchor: [0, -50],
    className: "custom-marker",
  });
}

/* ─── Map auto-fit component ────────────────────────────── */
function FitBounds({ points }) {
  const map = useMap();
  useEffect(() => {
    if (points.length > 0) {
      const bounds = L.latLngBounds(
        points.map((p) => [p.latitude, p.longitude])
      );
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 17 });
    }
  }, [points, map]);
  return null;
}

export default function MapPage() {
  const [heatmap, setHeatmap] = useState([]);
  const [areas, setAreas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedArea, setSelectedArea] = useState(null);

  const fetchData = useCallback(async () => {
    try {
      const [hmRes, areasRes] = await Promise.all([
        occupancyApi.heatmap(),
        areasApi.list(),
      ]);
      setHeatmap(hmRes.data);
      setAreas(areasRes.data);
    } catch (err) {
      console.error("Map fetch error:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // WebSocket updates
  const handleWsMessage = useCallback((msg) => {
    setHeatmap((prev) => {
      const idx = prev.findIndex((h) => h.area_id === msg.area_id);
      if (idx >= 0) {
        const copy = [...prev];
        copy[idx] = {
          ...copy[idx],
          occupancy_pct: msg.occupancy_pct,
          status: msg.status,
        };
        return copy;
      }
      return prev;
    });
  }, []);

  const { connected } = useWebSocket(null, handleWsMessage);

  const validPoints = heatmap.filter(
    (h) => h.latitude != null && h.longitude != null
  );

  // Default center: Istanbul if no points
  const defaultCenter = [41.0082, 28.9784];

  if (loading) {
    return (
      <div className="page-loader">
        <div className="loader-spinner" />
        <p>Harita yükleniyor…</p>
      </div>
    );
  }

  return (
    <div className="map-page">
      <div className="page-header">
        <div>
          <h1>Kampüs Haritası</h1>
          <p className="page-subtitle">Anlık doluluk durumu — harita görünümü</p>
        </div>
        <div className={`ws-status ${connected ? "connected" : "disconnected"}`}>
          {connected ? <Wifi size={16} /> : <WifiOff size={16} />}
          <span>{connected ? "Canlı" : "Bağlantı kesildi"}</span>
        </div>
      </div>

      <div className="map-wrapper">
        {/* ─── Legend ─────────────────────────────────── */}
        <div className="map-legend">
          <h4><Layers size={14} /> Doluluk Durumu</h4>
          {["empty", "low", "medium", "high", "full"].map((s) => (
            <div key={s} className="legend-item">
              <span
                className="legend-dot"
                style={{ background: statusColor(s) }}
              />
              <span>{statusLabel(s)}</span>
            </div>
          ))}
        </div>

        {/* ─── Sidebar ────────────────────────────────── */}
        <div className="map-sidebar">
          <h3>Alanlar</h3>
          <div className="map-area-list">
            {heatmap.map((h) => (
              <button
                key={h.area_id}
                className={`map-area-item ${
                  selectedArea === h.area_id ? "selected" : ""
                }`}
                onClick={() => setSelectedArea(h.area_id)}
                id={`map-area-${h.area_id}`}
              >
                <span
                  className="area-dot"
                  style={{ background: statusColor(h.status) }}
                />
                <div className="area-info">
                  <span className="area-name">{h.area_name}</span>
                  <span
                    className="area-pct"
                    style={{ color: statusColor(h.status) }}
                  >
                    {formatPercent(h.occupancy_pct)}
                  </span>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* ─── Map ────────────────────────────────────── */}
        <div className="map-container" id="campus-map">
          <MapContainer
            center={
              validPoints.length > 0
                ? [validPoints[0].latitude, validPoints[0].longitude]
                : defaultCenter
            }
            zoom={16}
            style={{ width: "100%", height: "100%" }}
            zoomControl={false}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            />
            {validPoints.length > 0 && <FitBounds points={validPoints} />}
            {validPoints.map((point) => (
              <Marker
                key={point.area_id}
                position={[point.latitude, point.longitude]}
                icon={createIcon(point.status, point.occupancy_pct)}
              >
                <Popup className="custom-popup">
                  <div className="popup-content">
                    <h4>{point.area_name}</h4>
                    <div className="popup-stats">
                      <div
                        className="popup-badge"
                        style={{
                          color: statusColor(point.status),
                          background: statusBg(point.status),
                        }}
                      >
                        {statusLabel(point.status)}
                      </div>
                      <span className="popup-pct">
                        {formatPercent(point.occupancy_pct)}
                      </span>
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>
      </div>

      {/* No data message */}
      {validPoints.length === 0 && heatmap.length > 0 && (
        <div className="map-no-geo">
          <Navigation size={32} />
          <p>
            Alanların haritada görünebilmesi için konum bilgisi (latitude/longitude)
            eklenmelidir.
          </p>
        </div>
      )}
    </div>
  );
}
