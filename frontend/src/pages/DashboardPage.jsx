import { useState, useEffect, useCallback, useRef } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { occupancyApi } from "../api/client";
import useWebSocket from "../hooks/useWebSocket";
import useCountUp from "../hooks/useCountUp";
import useWsToast from "../hooks/useWsToast";
import { DashboardSkeleton } from "../components/Skeleton";
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
  Clock,
  ChevronRight,
  AlertTriangle,
  X,
} from "lucide-react";
import WsStatusPill from "../components/WsStatusPill";
import { useNavigate } from "react-router-dom";

export default function DashboardPage() {
  const [liveData, setLiveData] = useState([]);
  const [summary, setSummary] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState("");
  const [pulsing, setPulsing] = useState(() => new Set());
  const pulseTimers = useRef(new Map());
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

    setPulsing((prev) => {
      const next = new Set(prev);
      next.add(msg.area_id);
      return next;
    });
    const prevTimer = pulseTimers.current.get(msg.area_id);
    if (prevTimer) clearTimeout(prevTimer);
    const t = setTimeout(() => {
      setPulsing((prev) => {
        const next = new Set(prev);
        next.delete(msg.area_id);
        return next;
      });
      pulseTimers.current.delete(msg.area_id);
    }, 1000);
    pulseTimers.current.set(msg.area_id, t);
  }, []);

  useEffect(() => {
    const timers = pulseTimers.current;
    return () => {
      timers.forEach((t) => clearTimeout(t));
      timers.clear();
    };
  }, []);

  const { connected } = useWebSocket(null, handleWsMessage, { throttleMs: 250 });
  useWsToast(connected);

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

  const animatedAreas = useCountUp(totalAreas);
  const animatedDevices = useCountUp(totalDevices);
  const animatedAvg = useCountUp(avgOccupancy, { decimals: 1 });
  const reduceMotion = useReducedMotion();

  if (loading) {
    return <DashboardSkeleton />;
  }

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <div>
          <h1>Genel Bakış</h1>
          <p className="page-subtitle">Kampüs alanlarının anlık doluluk durumu</p>
        </div>
        <WsStatusPill connected={connected} />
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
            <span className="stat-value">{animatedAreas}</span>
          </div>
        </div>
        <div className="stat-card stat-blue">
          <div className="stat-icon">
            <Users size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">Algılanan Cihaz</span>
            <span className="stat-value">{animatedDevices}</span>
          </div>
        </div>
        <div className="stat-card stat-amber">
          <div className="stat-icon">
            <TrendingUp size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-label">Ort. Doluluk</span>
            <span className="stat-value">{formatPercent(animatedAvg)}</span>
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
          <div
            className="area-cards-grid"
            aria-live="polite"
            aria-atomic="false"
          >
            <AnimatePresence initial={false}>
            {liveData.map((area) => (
              <motion.div
                key={area.area_id}
                layout={!reduceMotion}
                initial={reduceMotion ? false : { opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={reduceMotion ? { opacity: 0 } : { opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.28, ease: [0.4, 0, 0.2, 1] }}
                className={`area-card${pulsing.has(area.area_id) ? " pulse" : ""}`}
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
              </motion.div>
            ))}
            </AnimatePresence>
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
