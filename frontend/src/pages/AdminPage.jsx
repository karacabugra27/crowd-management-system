import { useState, useEffect, useCallback, useMemo } from "react";
import { adminApi, areasApi } from "../api/client";
import { formatPercent, formatDate, statusLabel } from "../utils/helpers";
import { translateError } from "../utils/errors";
import {
  Users,
  MapPin,
  Activity,
  Cpu,
  Plus,
  Trash2,
  ToggleLeft,
  ToggleRight,
  X,
  Shield,
  Copy,
  Check,
  AlertTriangle,
  ScrollText,
  LayoutGrid,
  RefreshCw,
} from "lucide-react";

const TABS = [
  { key: "overview", label: "Genel Bakış", icon: LayoutGrid },
  { key: "areas", label: "Alanlar", icon: MapPin },
  { key: "scanners", label: "Tarayıcılar", icon: Cpu },
  { key: "logs", label: "Loglar", icon: ScrollText },
];

export default function AdminPage() {
  const [activeTab, setActiveTab] = useState("overview");

  const [stats, setStats] = useState(null);
  const [areas, setAreas] = useState([]);
  const [scanners, setScanners] = useState([]);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [logsLoading, setLogsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");

  const [logLimit, setLogLimit] = useState(50);
  const [logAreaFilter, setLogAreaFilter] = useState("");

  const [showAreaModal, setShowAreaModal] = useState(false);
  const [showScannerModal, setShowScannerModal] = useState(false);
  const [newApiKey, setNewApiKey] = useState(null);
  const [copied, setCopied] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(null);

  const [areaForm, setAreaForm] = useState({
    name: "",
    floor: "",
    capacity: "",
    latitude: "",
    longitude: "",
  });
  const [scannerForm, setScannerForm] = useState({ name: "", area_id: "" });
  const [formError, setFormError] = useState("");

  const areaNameById = useMemo(
    () => new Map(areas.map((a) => [a.id, a.name])),
    [areas]
  );

  const fetchAll = useCallback(async () => {
    try {
      const [dashRes, areasRes, scannersRes] = await Promise.all([
        adminApi.dashboard(),
        areasApi.list(),
        adminApi.listScanners(),
      ]);
      setStats(dashRes.data);
      setAreas(areasRes.data);
      setScanners(scannersRes.data);
      setErrorMsg("");
    } catch (err) {
      setErrorMsg(translateError(err, "Yönetim verileri yüklenemedi."));
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchLogs = useCallback(async () => {
    setLogsLoading(true);
    try {
      const params = { limit: logLimit };
      if (logAreaFilter) params.area_id = Number(logAreaFilter);
      const { data } = await adminApi.logs(params);
      setLogs(data);
    } catch (err) {
      setErrorMsg(translateError(err, "Loglar yüklenemedi."));
    } finally {
      setLogsLoading(false);
    }
  }, [logLimit, logAreaFilter]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  useEffect(() => {
    if (activeTab === "logs") fetchLogs();
  }, [activeTab, fetchLogs]);

  const handleCreateArea = async (e) => {
    e.preventDefault();
    setFormError("");
    try {
      const payload = {
        name: areaForm.name.trim(),
        capacity: parseInt(areaForm.capacity, 10),
      };
      if (areaForm.floor) payload.floor = parseInt(areaForm.floor, 10);
      if (areaForm.latitude) payload.latitude = parseFloat(areaForm.latitude);
      if (areaForm.longitude) payload.longitude = parseFloat(areaForm.longitude);

      await areasApi.create(payload);
      setShowAreaModal(false);
      setAreaForm({ name: "", floor: "", capacity: "", latitude: "", longitude: "" });
      fetchAll();
    } catch (err) {
      setFormError(translateError(err, "Alan oluşturulamadı."));
    }
  };

  const handleToggleArea = async (id) => {
    try {
      await areasApi.toggleActive(id);
      fetchAll();
    } catch (err) {
      setErrorMsg(translateError(err, "Alan durumu değiştirilemedi."));
    }
  };

  const handleDeleteArea = async (id) => {
    try {
      await areasApi.delete(id);
      setDeleteConfirm(null);
      fetchAll();
    } catch (err) {
      setErrorMsg(translateError(err, "Alan silinemedi."));
    }
  };

  const handleCreateScanner = async (e) => {
    e.preventDefault();
    setFormError("");
    try {
      const payload = { name: scannerForm.name.trim() };
      if (scannerForm.area_id) payload.area_id = parseInt(scannerForm.area_id, 10);
      const { data } = await adminApi.createScanner(payload);
      setNewApiKey(data.api_key);
      setScannerForm({ name: "", area_id: "" });
      fetchAll();
    } catch (err) {
      setFormError(translateError(err, "Tarayıcı oluşturulamadı."));
    }
  };

  const handleDeleteScanner = async (id) => {
    try {
      await adminApi.deleteScanner(id);
      setDeleteConfirm(null);
      fetchAll();
    } catch (err) {
      setErrorMsg(translateError(err, "Tarayıcı silinemedi."));
    }
  };

  const copyApiKey = () => {
    navigator.clipboard.writeText(newApiKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (loading) {
    return (
      <div className="page-loader">
        <div className="loader-spinner" />
        <p>Yönetim paneli yükleniyor…</p>
      </div>
    );
  }

  return (
    <div className="admin-page">
      <div className="page-header">
        <div>
          <h1>
            <Shield size={28} className="header-icon" /> Yönetim Paneli
          </h1>
          <p className="page-subtitle">Alan, tarayıcı ve doluluk loglarını yönetin</p>
        </div>
        <button className="btn btn-ghost" onClick={fetchAll} title="Yenile">
          <RefreshCw size={16} /> Yenile
        </button>
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

      <div className="tab-bar" role="tablist">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            role="tab"
            aria-selected={activeTab === tab.key}
            className={`tab-btn ${activeTab === tab.key ? "active" : ""}`}
            onClick={() => setActiveTab(tab.key)}
          >
            <tab.icon size={16} />
            <span>{tab.label}</span>
          </button>
        ))}
      </div>

      {activeTab === "overview" && (
        <OverviewTab stats={stats} areaCount={areas.length} scannerCount={scanners.length} />
      )}

      {activeTab === "areas" && (
        <AreasTab
          areas={areas}
          onAdd={() => setShowAreaModal(true)}
          onToggle={handleToggleArea}
          onDelete={(a) => setDeleteConfirm({ type: "area", id: a.id, name: a.name })}
        />
      )}

      {activeTab === "scanners" && (
        <ScannersTab
          scanners={scanners}
          onAdd={() => {
            setShowScannerModal(true);
            setNewApiKey(null);
          }}
          onDelete={(s) => setDeleteConfirm({ type: "scanner", id: s.id, name: s.name })}
        />
      )}

      {activeTab === "logs" && (
        <LogsTab
          logs={logs}
          loading={logsLoading}
          areas={areas}
          areaFilter={logAreaFilter}
          onAreaFilterChange={setLogAreaFilter}
          limit={logLimit}
          onLimitChange={setLogLimit}
          onRefresh={fetchLogs}
          areaNameById={areaNameById}
        />
      )}

      {showAreaModal && (
        <AreaModal
          form={areaForm}
          setForm={setAreaForm}
          formError={formError}
          onClose={() => {
            setShowAreaModal(false);
            setFormError("");
          }}
          onSubmit={handleCreateArea}
        />
      )}

      {showScannerModal && (
        <ScannerModal
          form={scannerForm}
          setForm={setScannerForm}
          formError={formError}
          areas={areas}
          newApiKey={newApiKey}
          copied={copied}
          onClose={() => {
            setShowScannerModal(false);
            setNewApiKey(null);
            setFormError("");
          }}
          onSubmit={handleCreateScanner}
          onCopy={copyApiKey}
        />
      )}

      {deleteConfirm && (
        <DeleteConfirmModal
          target={deleteConfirm}
          onClose={() => setDeleteConfirm(null)}
          onConfirm={() =>
            deleteConfirm.type === "area"
              ? handleDeleteArea(deleteConfirm.id)
              : handleDeleteScanner(deleteConfirm.id)
          }
        />
      )}
    </div>
  );
}

/* ───────────────────────── Tabs ────────────────────────── */

function OverviewTab({ stats, areaCount, scannerCount }) {
  if (!stats) return <div className="empty-state">Veri bulunamadı.</div>;

  const cards = [
    {
      tone: "purple",
      icon: MapPin,
      label: "Toplam Alan",
      value: stats.total_areas ?? areaCount,
      meta: `${stats.active_areas ?? 0} aktif`,
    },
    {
      tone: "blue",
      icon: Activity,
      label: "Aktif Alan",
      value: stats.active_areas ?? 0,
      meta: "Şu anda yayında",
    },
    {
      tone: "amber",
      icon: Users,
      label: "Kullanıcı",
      value: stats.total_users ?? 0,
      meta: "Kayıtlı yönetici",
    },
    {
      tone: "rose",
      icon: Cpu,
      label: "Ortalama Doluluk",
      value: `${formatPercent(stats.avg_occupancy ?? 0)}`,
      meta: `${scannerCount} tarayıcı`,
    },
  ];

  return (
    <>
      <div className="stats-grid">
        {cards.map((card) => (
          <div className={`stat-card stat-${card.tone}`} key={card.label}>
            <div className="stat-icon">
              <card.icon size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-label">{card.label}</span>
              <span className="stat-value">{card.value}</span>
              <span className="stat-meta">{card.meta}</span>
            </div>
          </div>
        ))}
      </div>

      {(stats.busiest_area || stats.emptiest_area) && (
        <section className="section">
          <div className="section-header">
            <h2>Öne Çıkan Alanlar</h2>
          </div>
          <div className="highlight-grid">
            {stats.busiest_area && (
              <div className="highlight-card highlight-warm">
                <span className="highlight-tag">En Yoğun</span>
                <strong>{stats.busiest_area.area_name}</strong>
                <span>{formatPercent(stats.busiest_area.occupancy_pct ?? 0)} doluluk</span>
              </div>
            )}
            {stats.emptiest_area && (
              <div className="highlight-card highlight-cool">
                <span className="highlight-tag">En Sakin</span>
                <strong>{stats.emptiest_area.area_name}</strong>
                <span>{formatPercent(stats.emptiest_area.occupancy_pct ?? 0)} doluluk</span>
              </div>
            )}
          </div>
        </section>
      )}
    </>
  );
}

function AreasTab({ areas, onAdd, onToggle, onDelete }) {
  return (
    <section className="section">
      <div className="section-header">
        <h2>Alanlar ({areas.length})</h2>
        <button className="btn btn-primary" onClick={onAdd}>
          <Plus size={16} /> Yeni Alan
        </button>
      </div>
      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Alan Adı</th>
              <th>Kat</th>
              <th>Kapasite</th>
              <th>Konum</th>
              <th>Durum</th>
              <th>Oluşturulma</th>
              <th>İşlemler</th>
            </tr>
          </thead>
          <tbody>
            {areas.map((a) => (
              <tr key={a.id} className={!a.is_active ? "row-inactive" : ""}>
                <td>{a.id}</td>
                <td className="td-name">{a.name}</td>
                <td>{a.floor ?? "—"}</td>
                <td>{a.capacity}</td>
                <td>
                  {a.latitude && a.longitude
                    ? `${a.latitude.toFixed(4)}, ${a.longitude.toFixed(4)}`
                    : "—"}
                </td>
                <td>
                  <span className={`status-pill ${a.is_active ? "active" : "inactive"}`}>
                    {a.is_active ? "Aktif" : "Pasif"}
                  </span>
                </td>
                <td>{formatDate(a.created_at)}</td>
                <td>
                  <div className="action-btns">
                    <button
                      className="icon-btn"
                      onClick={() => onToggle(a.id)}
                      title={a.is_active ? "Pasife al" : "Aktifleştir"}
                    >
                      {a.is_active ? (
                        <ToggleRight size={18} className="text-green" />
                      ) : (
                        <ToggleLeft size={18} className="text-gray" />
                      )}
                    </button>
                    <button
                      className="icon-btn danger"
                      onClick={() => onDelete(a)}
                      title="Sil"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {areas.length === 0 && (
              <tr>
                <td colSpan={8} className="empty-td">
                  Henüz alan eklenmemiş.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function ScannersTab({ scanners, onAdd, onDelete }) {
  return (
    <section className="section">
      <div className="section-header">
        <h2>Tarayıcılar ({scanners.length})</h2>
        <button className="btn btn-primary" onClick={onAdd}>
          <Plus size={16} /> Yeni Tarayıcı
        </button>
      </div>
      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Ad</th>
              <th>Alan ID</th>
              <th>Son Görülme</th>
              <th>Durum</th>
              <th>İşlemler</th>
            </tr>
          </thead>
          <tbody>
            {scanners.map((s) => (
              <tr key={s.id}>
                <td>{s.id}</td>
                <td className="td-name">{s.name || "—"}</td>
                <td>{s.area_id ?? "—"}</td>
                <td>{formatDate(s.last_seen)}</td>
                <td>
                  <span className={`status-pill ${s.is_active ? "active" : "inactive"}`}>
                    {s.is_active ? "Aktif" : "Pasif"}
                  </span>
                </td>
                <td>
                  <button
                    className="icon-btn danger"
                    onClick={() => onDelete(s)}
                    title="Sil"
                  >
                    <Trash2 size={16} />
                  </button>
                </td>
              </tr>
            ))}
            {scanners.length === 0 && (
              <tr>
                <td colSpan={6} className="empty-td">
                  Henüz tarayıcı eklenmemiş.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function LogsTab({
  logs,
  loading,
  areas,
  areaFilter,
  onAreaFilterChange,
  limit,
  onLimitChange,
  onRefresh,
  areaNameById,
}) {
  return (
    <section className="section">
      <div className="section-header">
        <h2>Bluetooth Doluluk Logları</h2>
        <div className="toolbar-controls">
          <select
            value={areaFilter}
            onChange={(e) => onAreaFilterChange(e.target.value)}
            aria-label="Alan filtresi"
          >
            <option value="">Tüm alanlar</option>
            {areas.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name} (#{a.id})
              </option>
            ))}
          </select>
          <select
            value={limit}
            onChange={(e) => onLimitChange(Number(e.target.value))}
            aria-label="Kayıt sayısı"
          >
            <option value={25}>Son 25 kayıt</option>
            <option value={50}>Son 50 kayıt</option>
            <option value={100}>Son 100 kayıt</option>
            <option value={200}>Son 200 kayıt</option>
          </select>
          <button className="btn btn-ghost" onClick={onRefresh}>
            <RefreshCw size={14} /> Yenile
          </button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Zaman</th>
              <th>Alan</th>
              <th>Cihaz Sayısı</th>
              <th>Doluluk</th>
              <th>Durum</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={5} className="empty-td">
                  Loglar yükleniyor…
                </td>
              </tr>
            )}
            {!loading && logs.length === 0 && (
              <tr>
                <td colSpan={5} className="empty-td">
                  Bu filtre için kayıt bulunamadı.
                </td>
              </tr>
            )}
            {!loading &&
              logs.map((log, i) => (
                <tr key={`${log.recorded_at}-${i}`}>
                  <td>{formatDate(log.recorded_at)}</td>
                  <td>
                    {log.area_id
                      ? areaNameById.get(log.area_id) || `Alan #${log.area_id}`
                      : "—"}
                  </td>
                  <td>{log.device_count ?? 0}</td>
                  <td>{formatPercent(log.occupancy_pct ?? 0)}</td>
                  <td>
                    <span className={`status-pill status-${log.status || "empty"}`}>
                      {statusLabel(log.status)}
                    </span>
                  </td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

/* ───────────────────────── Modals ──────────────────────── */

function AreaModal({ form, setForm, formError, onClose, onSubmit }) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Yeni Alan Ekle</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        {formError && <div className="modal-error">{formError}</div>}
        <form onSubmit={onSubmit} className="modal-form">
          <div className="form-group">
            <label htmlFor="area-name">Alan Adı *</label>
            <input
              id="area-name"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
              placeholder="Örn: Kütüphane - 1. Kat"
            />
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="area-floor">Kat</label>
              <input
                id="area-floor"
                type="number"
                value={form.floor}
                onChange={(e) => setForm({ ...form, floor: e.target.value })}
                placeholder="Örn: 1"
              />
            </div>
            <div className="form-group">
              <label htmlFor="area-capacity">Kapasite *</label>
              <input
                id="area-capacity"
                type="number"
                min="1"
                value={form.capacity}
                onChange={(e) => setForm({ ...form, capacity: e.target.value })}
                required
                placeholder="Örn: 200"
              />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="area-lat">Enlem</label>
              <input
                id="area-lat"
                type="number"
                step="any"
                value={form.latitude}
                onChange={(e) => setForm({ ...form, latitude: e.target.value })}
                placeholder="Örn: 41.0082"
              />
            </div>
            <div className="form-group">
              <label htmlFor="area-lng">Boylam</label>
              <input
                id="area-lng"
                type="number"
                step="any"
                value={form.longitude}
                onChange={(e) => setForm({ ...form, longitude: e.target.value })}
                placeholder="Örn: 28.9784"
              />
            </div>
          </div>
          <button type="submit" className="btn btn-primary btn-full">
            <Plus size={16} /> Alan Oluştur
          </button>
        </form>
      </div>
    </div>
  );
}

function ScannerModal({
  form,
  setForm,
  formError,
  areas,
  newApiKey,
  copied,
  onClose,
  onSubmit,
  onCopy,
}) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>{newApiKey ? "Tarayıcı Oluşturuldu" : "Yeni Tarayıcı"}</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        {newApiKey ? (
          <div className="api-key-display">
            <div className="api-key-warning">
              <AlertTriangle size={18} />
              <span>
                Bu API anahtarı yalnızca bir kez gösterilir. Lütfen güvenli bir
                yere kaydedin.
              </span>
            </div>
            <div className="api-key-box">
              <code>{newApiKey}</code>
              <button onClick={onCopy} className="copy-btn" title="Kopyala">
                {copied ? <Check size={16} /> : <Copy size={16} />}
              </button>
            </div>
            <button className="btn btn-primary btn-full" onClick={onClose}>
              Tamam
            </button>
          </div>
        ) : (
          <>
            {formError && <div className="modal-error">{formError}</div>}
            <form onSubmit={onSubmit} className="modal-form">
              <div className="form-group">
                <label htmlFor="scanner-name">Tarayıcı Adı *</label>
                <input
                  id="scanner-name"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  required
                  placeholder="Örn: Kütüphane-Scanner-01"
                />
              </div>
              <div className="form-group">
                <label htmlFor="scanner-area">Alan (Opsiyonel)</label>
                <select
                  id="scanner-area"
                  value={form.area_id}
                  onChange={(e) => setForm({ ...form, area_id: e.target.value })}
                >
                  <option value="">— Seçilmedi —</option>
                  {areas.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name}
                    </option>
                  ))}
                </select>
              </div>
              <button type="submit" className="btn btn-primary btn-full">
                <Plus size={16} /> Tarayıcı Oluştur
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  );
}

function DeleteConfirmModal({ target, onClose, onConfirm }) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal modal-sm" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Silme Onayı</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="modal-body">
          <AlertTriangle size={32} className="text-warning" />
          <p>
            <strong>{target.name || `#${target.id}`}</strong>{" "}
            {target.type === "area" ? "alanını" : "tarayıcısını"} silmek
            istediğinize emin misiniz? Bu işlem geri alınamaz.
          </p>
        </div>
        <div className="modal-actions">
          <button className="btn btn-ghost" onClick={onClose}>
            Vazgeç
          </button>
          <button className="btn btn-danger" onClick={onConfirm}>
            <Trash2 size={16} /> Sil
          </button>
        </div>
      </div>
    </div>
  );
}
