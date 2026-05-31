import { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "react-router-dom";
import { occupancyApi, areasApi } from "../api/client";
import {
  statusColor,
  statusLabel,
  formatPercent,
  formatTime,
} from "../utils/helpers";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
} from "recharts";
import { Clock, TrendingUp, BarChart3, Filter } from "lucide-react";

export default function AnalyticsPage() {
  const [searchParams] = useSearchParams();
  const initialArea = searchParams.get("area");

  const [areas, setAreas] = useState([]);
  const [selectedArea, setSelectedArea] = useState(initialArea || "");
  const [hours, setHours] = useState(24);
  const [history, setHistory] = useState([]);
  const [summary, setSummary] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchAreas = useCallback(async () => {
    try {
      const { data } = await areasApi.list();
      setAreas(data);
      if (!selectedArea && data.length > 0) {
        setSelectedArea(String(data[0].id));
      }
    } catch (err) {
      console.error(err);
    }
  }, []);

  useEffect(() => {
    fetchAreas();
  }, [fetchAreas]);

  const fetchHistory = useCallback(async () => {
    if (!selectedArea) return;
    setLoading(true);
    try {
      const [histRes, sumRes] = await Promise.all([
        occupancyApi.history(selectedArea, hours),
        occupancyApi.summary(),
      ]);
      // Reverse to chronological order
      setHistory(histRes.data.reverse());
      setSummary(sumRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [selectedArea, hours]);

  useEffect(() => {
    fetchHistory();
  }, [fetchHistory]);

  const areaSummary = summary.find(
    (s) => String(s.area_id) === String(selectedArea)
  );
  const areaName =
    areas.find((a) => String(a.id) === String(selectedArea))?.name || "";

  const chartData = history.map((h) => ({
    time: formatTime(h.recorded_at),
    occupancy: Math.round(h.occupancy_pct),
    devices: h.device_count,
    status: h.status,
  }));

  return (
    <div className="analytics-page">
      <div className="page-header">
        <div>
          <h1>Analitik</h1>
          <p className="page-subtitle">Geçmiş doluluk verileri ve trendler</p>
        </div>
      </div>

      {/* ─── Filters ─────────────────────────────────── */}
      <div className="analytics-filters">
        <div className="filter-group">
          <label htmlFor="area-select">
            <Filter size={16} /> Alan
          </label>
          <select
            id="area-select"
            value={selectedArea}
            onChange={(e) => setSelectedArea(e.target.value)}
          >
            {areas.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-group">
          <label htmlFor="hours-select">
            <Clock size={16} /> Süre
          </label>
          <select
            id="hours-select"
            value={hours}
            onChange={(e) => setHours(Number(e.target.value))}
          >
            <option value={1}>Son 1 Saat</option>
            <option value={6}>Son 6 Saat</option>
            <option value={12}>Son 12 Saat</option>
            <option value={24}>Son 24 Saat</option>
            <option value={72}>Son 3 Gün</option>
            <option value={168}>Son 1 Hafta</option>
          </select>
        </div>
      </div>

      {/* ─── Summary Cards ───────────────────────────── */}
      {areaSummary && (
        <div className="analytics-summary-cards">
          <div className="analytics-stat">
            <TrendingUp size={20} />
            <div>
              <span className="analytics-stat-label">Ort. Doluluk</span>
              <span className="analytics-stat-value">
                {formatPercent(areaSummary.avg_occupancy)}
              </span>
            </div>
          </div>
          <div className="analytics-stat">
            <BarChart3 size={20} />
            <div>
              <span className="analytics-stat-label">Maks. Doluluk</span>
              <span className="analytics-stat-value">
                {formatPercent(areaSummary.max_occupancy)}
              </span>
            </div>
          </div>
          <div className="analytics-stat">
            <Clock size={20} />
            <div>
              <span className="analytics-stat-label">Pik Saati</span>
              <span className="analytics-stat-value">
                {areaSummary.peak_hour !== null && areaSummary.peak_hour !== undefined
                  ? `${String(areaSummary.peak_hour).padStart(2, "0")}:00`
                  : "—"}
              </span>
            </div>
          </div>
        </div>
      )}

      {loading ? (
        <div className="page-loader">
          <div className="loader-spinner" />
          <p>Geçmiş veriler yükleniyor…</p>
        </div>
      ) : (
        <>
          {/* ─── Occupancy Chart ─────────────────────── */}
          <section className="section chart-section">
            <div className="section-header">
              <h2>
                {areaName} — Doluluk Trendi ({hours} saat)
              </h2>
            </div>
            <div className="chart-container">
              {chartData.length === 0 ? (
                <div className="empty-state">
                  <BarChart3 size={48} />
                  <h3>Bu dönem için veri yok</h3>
                  <p>Seçili dönemde doluluk kaydı bulunmuyor.</p>
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={350}>
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id="gradOcc" x1="0" y1="0" x2="0" y2="1">
                        <stop
                          offset="0%"
                          stopColor="#818cf8"
                          stopOpacity={0.4}
                        />
                        <stop
                          offset="100%"
                          stopColor="#818cf8"
                          stopOpacity={0.05}
                        />
                      </linearGradient>
                    </defs>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="rgba(255,255,255,0.06)"
                    />
                    <XAxis
                      dataKey="time"
                      stroke="#6b7280"
                      fontSize={12}
                      tickLine={false}
                    />
                    <YAxis
                      stroke="#6b7280"
                      fontSize={12}
                      tickLine={false}
                      domain={[0, 100]}
                      tickFormatter={(v) => `${v}%`}
                    />
                    <Tooltip
                      contentStyle={{
                        background: "#1e1e2e",
                        border: "1px solid rgba(255,255,255,0.1)",
                        borderRadius: "12px",
                        color: "#e2e8f0",
                      }}
                      formatter={(val) => [`${val}%`, "Doluluk"]}
                    />
                    <Area
                      type="monotone"
                      dataKey="occupancy"
                      stroke="#818cf8"
                      fill="url(#gradOcc)"
                      strokeWidth={2.5}
                      dot={false}
                      activeDot={{ r: 5, fill: "#818cf8" }}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </section>

          {/* ─── Device count chart ──────────────────── */}
          {chartData.length > 0 && (
            <section className="section chart-section">
              <div className="section-header">
                <h2>Cihaz Sayısı</h2>
              </div>
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={chartData}>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="rgba(255,255,255,0.06)"
                    />
                    <XAxis
                      dataKey="time"
                      stroke="#6b7280"
                      fontSize={12}
                      tickLine={false}
                    />
                    <YAxis
                      stroke="#6b7280"
                      fontSize={12}
                      tickLine={false}
                    />
                    <Tooltip
                      contentStyle={{
                        background: "#1e1e2e",
                        border: "1px solid rgba(255,255,255,0.1)",
                        borderRadius: "12px",
                        color: "#e2e8f0",
                      }}
                      formatter={(val) => [val, "Cihaz"]}
                    />
                    <Bar
                      dataKey="devices"
                      fill="#6366f1"
                      radius={[6, 6, 0, 0]}
                      maxBarSize={40}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </section>
          )}
        </>
      )}
    </div>
  );
}
