import { useState, useEffect, useCallback } from "react";
import { occupancyApi } from "../api/client";
import useWebSocket from "../hooks/useWebSocket";
import {
  statusColor,
  statusLabel,
  statusBg,
  formatPercent,
  formatDate,
} from "../utils/helpers";
import { translateError } from "../utils/errors";
import {
  Users,
  MapPin,
  TrendingUp,
  Activity,
  Wifi,
  WifiOff,
  Clock,
  ChevronRight,
  AlertTriangle,
  X,
} from "lucide-react";
import { useNavigate } from "react-router-dom";

export default function DashboardPage() {
  const [liveData, setLiveData] = useState([]);
  const [summary, setSummary] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState("");
  const navigate = useNavigate();

  const fetchData = useCallback(async () => {
    try {
      const [liveRes, summaryRes] = await Promise.all([
        occupancyApi.live(),
        occupancyApi.summary(),
      ]);
      setLiveData(liveRes.data);
      setSummary(summaryRes.data);
      setErrorMsg("");
    } catch (err) {
      setErrorMsg(translateError(err, "Doluluk verileri yüklenemedi."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Real-time updates via WebSocket
  const handleWsMessage = useCallback((msg) => {
    setLiveData((prev) => {
      const idx = prev.findIndex((a) => a.area_id === msg.area_id);
      const updated = {
        area_id: msg.area_id,
        area_name: msg.area_name,
        device_count: msg.device_count,
        occupancy_pct: msg.occupancy_pct,
        status: msg.status,
        last_updated: msg.recorded_at,
      };
      if (idx >= 0) {
        const copy = [...prev];
        copy[idx] = updated;
        return copy;
      }
      return [...prev, updated];
    });
  }, []);

  const { connected } = useWebSocket(null, handleWsMessage);

  // Stats
  const totalAreas = liveData.length;
  const totalDevices = liveData.reduce((s, a) => s + a.device_count, 0);
  const avgOccupancy =
    totalAreas > 0
      ? liveData.reduce((s, a) => s + a.occupancy_pct, 0) / totalAreas
      : 0;
  const busiestArea = liveData.length
    ? liveData.reduce((max, a) => (a.occupancy_pct > max.occupancy_pct ? a : max))
    : null;

  if (loading) {
    return (
      <div className="page-loader">
        <div className="loader-spinner" />
        <p>Veriler yükleniyor…</p>
      </div>
    );
  }

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <div>
          <h1>Genel Bakış</h1>
          <p className="page-subtitle">Kampüs alanlarının anlık doluluk durumu</p>
        </div>
        <div className={`ws-status ${connected ? "connected" : "disconnected"}`}>
          {connected ? <Wifi size={16} /> : <WifiOff size={16} />}
          <span>{connected ? "Canlı bağlantı" : "Bağlantı kesildi"}</span>
        </div>
      </div>

      {errorMsg && (
        <div className="alert alert-error">
          <AlertTriangle size={18} />
          <span>{errorMsg}</span>
          <button
            className="alert-close"
            onClick={() => setErrorMsg("")}
            aria-label="Kapat"
          >
            <X size={16} />
          </button>
        </div>
      )}

      {/* ─── Stat cards ─────────────────────────────────── */}
      <div className="stats-grid">
        <div className="stat-card stat-purple">
          <div className="stat-icon">
            <MapPin size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">Toplam Alan</span>
            <span className="stat-value">{totalAreas}</span>
          </div>
        </div>
        <div className="stat-card stat-blue">
          <div className="stat-icon">
            <Users size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">Algılanan Cihaz</span>
            <span className="stat-value">{totalDevices}</span>
          </div>
        </div>
        <div className="stat-card stat-amber">
          <div className="stat-icon">
            <TrendingUp size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">Ort. Doluluk</span>
            <span className="stat-value">{formatPercent(avgOccupancy)}</span>
          </div>
        </div>
        <div className="stat-card stat-rose">
          <div className="stat-icon">
            <Activity size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">En Yoğun</span>
            <span className="stat-value stat-value-sm">
              {busiestArea?.area_name || "—"}
            </span>
          </div>
        </div>
      </div>

      {/* ─── Area cards ─────────────────────────────────── */}
      <section className="section">
        <div className="section-header">
          <h2>Canlı Doluluk</h2>
          <button className="see-all-btn" onClick={() => navigate("/map")}>
            Haritada Gör <ChevronRight size={16} />
          </button>
        </div>

        {liveData.length === 0 ? (
          <div className="empty-state">
            <MapPin size={48} />
            <h3>Henüz alan verisi yok</h3>
            <p>Yönetim panelinden alan ekleyerek başlayın.</p>
          </div>
        ) : (
          <div className="area-cards-grid">
            {liveData.map((area) => (
              <div
                key={area.area_id}
                className="area-card"
                onClick={() => navigate(`/analytics?area=${area.area_id}`)}
                id={`area-card-${area.area_id}`}
              >
                <div className="area-card-header">
                  <h3>{area.area_name}</h3>
                  <span
                    className="status-badge"
                    style={{
                      color: statusColor(area.status),
                      background: statusBg(area.status),
                    }}
                  >
                    {statusLabel(area.status)}
                  </span>
                </div>

                <div className="area-card-body">
                  <div className="occupancy-ring-container">
                    <svg className="occupancy-ring" viewBox="0 0 100 100">
                      <circle
                        className="ring-bg"
                        cx="50"
                        cy="50"
                        r="42"
                      />
                      <circle
                        className="ring-fill"
                        cx="50"
                        cy="50"
                        r="42"
                        style={{
                          stroke: statusColor(area.status),
                          strokeDasharray: `${(area.occupancy_pct / 100) * 264} 264`,
                        }}
                      />
                    </svg>
                    <div className="ring-text">
                      <span className="ring-pct">
                        {Math.round(area.occupancy_pct)}
                      </span>
                      <span className="ring-unit">%</span>
                    </div>
                  </div>

                  <div className="area-card-stats">
                    <div className="area-stat">
                      <Users size={14} />
                      <span>{area.device_count} cihaz</span>
                    </div>
                    <div className="area-stat">
                      <Clock size={14} />
                      <span>{formatDate(area.last_updated)}</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* ─── Summary Table ──────────────────────────────── */}
      {summary.length > 0 && (
        <section className="section">
          <div className="section-header">
            <h2>Alan Özet İstatistikleri</h2>
          </div>
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Alan</th>
                  <th>Ort. Doluluk</th>
                  <th>Maks. Doluluk</th>
                  <th>Pik Saati</th>
                  <th>Toplam Kayıt</th>
                </tr>
              </thead>
              <tbody>
                {summary.map((s) => (
                  <tr key={s.area_id}>
                    <td className="td-name">{s.area_name}</td>
                    <td>{formatPercent(s.avg_occupancy)}</td>
                    <td>{formatPercent(s.max_occupancy)}</td>
                    <td>
                      {s.peak_hour !== null && s.peak_hour !== undefined
                        ? `${String(s.peak_hour).padStart(2, "0")}:00`
                        : "—"}
                    </td>
                    <td>{s.total_records.toLocaleString("tr-TR")}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
