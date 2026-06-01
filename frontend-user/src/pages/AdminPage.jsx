import { useState, useEffect, useCallback } from "react";
import { adminApi, areasApi } from "../api/client";
import { formatPercent, formatDate } from "../utils/helpers";
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
} from "lucide-react";

export default function AdminPage() {
  const [stats, setStats] = useState(null);
  const [areas, setAreas] = useState([]);
  const [scanners, setScanners] = useState([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showAreaModal, setShowAreaModal] = useState(false);
  const [showScannerModal, setShowScannerModal] = useState(false);
  const [newApiKey, setNewApiKey] = useState(null);
  const [copied, setCopied] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(null);

  // Forms
  const [areaForm, setAreaForm] = useState({
    name: "",
    floor: "",
    capacity: "",
    latitude: "",
    longitude: "",
  });
  const [scannerForm, setScannerForm] = useState({ name: "", area_id: "" });
  const [formError, setFormError] = useState("");

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
    } catch (err) {
      console.error("Admin fetch error:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  /* ─── Area CRUD ─────────────────────────────────────── */
  const handleCreateArea = async (e) => {
    e.preventDefault();
    setFormError("");
    try {
      const payload = {
        name: areaForm.name,
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
      setFormError(
        err.response?.data?.detail || "Alan oluşturulamadı."
      );
    }
  };

  const handleToggleArea = async (id) => {
    try {
      await areasApi.toggleActive(id);
      fetchAll();
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteArea = async (id) => {
    try {
      await areasApi.delete(id);
      setDeleteConfirm(null);
      fetchAll();
    } catch (err) {
      console.error(err);
    }
  };

  /* ─── Scanner CRUD ──────────────────────────────────── */
  const handleCreateScanner = async (e) => {
    e.preventDefault();
    setFormError("");
    try {
      const payload = { name: scannerForm.name };
      if (scannerForm.area_id)
        payload.area_id = parseInt(scannerForm.area_id, 10);

      const { data } = await adminApi.createScanner(payload);
      setNewApiKey(data.api_key);
      setScannerForm({ name: "", area_id: "" });
      fetchAll();
    } catch (err) {
      setFormError(
        err.response?.data?.detail || "Tarayıcı oluşturulamadı."
      );
    }
  };

  const handleDeleteScanner = async (id) => {
    try {
      await adminApi.deleteScanner(id);
      setDeleteConfirm(null);
      fetchAll();
    } catch (err) {
      console.error(err);
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
          <p className="page-subtitle">Alan ve tarayıcı yönetimi</p>
        </div>
      </div>

      {/* ─── Dashboard Stats ──────────────────────────── */}
      {stats && (
        <div className="stats-grid">
          <div className="stat-card stat-purple">
            <div className="stat-icon"><MapPin size={24} /></div>
            <div className="stat-content">
              <span className="stat-label">Toplam Alan</span>
              <span className="stat-value">{stats.total_areas}</span>
            </div>
          </div>
          <div className="stat-card stat-blue">
            <div className="stat-icon"><Activity size={24} /></div>
            <div className="stat-content">
              <span className="stat-label">Aktif Alan</span>
              <span className="stat-value">{stats.active_areas}</span>
            </div>
          </div>
          <div className="stat-card stat-amber">
            <div className="stat-icon"><Users size={24} /></div>
            <div className="stat-content">
              <span className="stat-label">Kullanıcılar</span>
              <span className="stat-value">{stats.total_users}</span>
            </div>
          </div>
          <div className="stat-card stat-rose">
            <div className="stat-icon"><Cpu size={24} /></div>
            <div className="stat-content">
              <span className="stat-label">Ort. Doluluk</span>
              <span className="stat-value">{formatPercent(stats.avg_occupancy)}</span>
            </div>
          </div>
        </div>
      )}

      {/* ─── Areas Table ──────────────────────────────── */}
      <section className="section">
        <div className="section-header">
          <h2>Alanlar ({areas.length})</h2>
          <button
            className="btn btn-primary"
            onClick={() => setShowAreaModal(true)}
            id="add-area-btn"
          >
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
                        onClick={() => handleToggleArea(a.id)}
                        title={a.is_active ? "Pasife Al" : "Aktifleştir"}
                        id={`toggle-area-${a.id}`}
                      >
                        {a.is_active ? (
                          <ToggleRight size={18} className="text-green" />
                        ) : (
                          <ToggleLeft size={18} className="text-gray" />
                        )}
                      </button>
                      <button
                        className="icon-btn danger"
                        onClick={() => setDeleteConfirm({ type: "area", id: a.id, name: a.name })}
                        title="Sil"
                        id={`delete-area-${a.id}`}
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

      {/* ─── Scanners Table ───────────────────────────── */}
      <section className="section">
        <div className="section-header">
          <h2>Tarayıcılar ({scanners.length})</h2>
          <button
            className="btn btn-primary"
            onClick={() => {
              setShowScannerModal(true);
              setNewApiKey(null);
            }}
            id="add-scanner-btn"
          >
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
                      onClick={() => setDeleteConfirm({ type: "scanner", id: s.id, name: s.name })}
                      title="Sil"
                      id={`delete-scanner-${s.id}`}
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

      {/* ─── Area Modal ───────────────────────────────── */}
      {showAreaModal && (
        <div className="modal-overlay" onClick={() => setShowAreaModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Yeni Alan Ekle</h3>
              <button className="modal-close" onClick={() => setShowAreaModal(false)}>
                <X size={20} />
              </button>
            </div>
            {formError && <div className="modal-error">{formError}</div>}
            <form onSubmit={handleCreateArea} className="modal-form">
              <div className="form-group">
                <label htmlFor="area-name">Alan Adı *</label>
                <input
                  id="area-name"
                  value={areaForm.name}
                  onChange={(e) => setAreaForm({ ...areaForm, name: e.target.value })}
                  required
                  placeholder="Ör: Kütüphane - 1. Kat"
                />
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="area-floor">Kat</label>
                  <input
                    id="area-floor"
                    type="number"
                    value={areaForm.floor}
                    onChange={(e) => setAreaForm({ ...areaForm, floor: e.target.value })}
                    placeholder="Ör: 1"
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="area-capacity">Kapasite *</label>
                  <input
                    id="area-capacity"
                    type="number"
                    min="1"
                    value={areaForm.capacity}
                    onChange={(e) => setAreaForm({ ...areaForm, capacity: e.target.value })}
                    required
                    placeholder="Ör: 200"
                  />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="area-lat">Latitude</label>
                  <input
                    id="area-lat"
                    type="number"
                    step="any"
                    value={areaForm.latitude}
                    onChange={(e) => setAreaForm({ ...areaForm, latitude: e.target.value })}
                    placeholder="Ör: 41.0082"
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="area-lng">Longitude</label>
                  <input
                    id="area-lng"
                    type="number"
                    step="any"
                    value={areaForm.longitude}
                    onChange={(e) => setAreaForm({ ...areaForm, longitude: e.target.value })}
                    placeholder="Ör: 28.9784"
                  />
                </div>
              </div>
              <button type="submit" className="btn btn-primary btn-full" id="submit-area">
                <Plus size={16} /> Alan Oluştur
              </button>
            </form>
          </div>
        </div>
      )}

      {/* ─── Scanner Modal ────────────────────────────── */}
      {showScannerModal && (
        <div className="modal-overlay" onClick={() => { setShowScannerModal(false); setNewApiKey(null); }}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{newApiKey ? "Tarayıcı Oluşturuldu" : "Yeni Tarayıcı"}</h3>
              <button className="modal-close" onClick={() => { setShowScannerModal(false); setNewApiKey(null); }}>
                <X size={20} />
              </button>
            </div>

            {newApiKey ? (
              <div className="api-key-display">
                <div className="api-key-warning">
                  <AlertTriangle size={18} />
                  <span>Bu API anahtarı yalnızca bir kez gösterilir!</span>
                </div>
                <div className="api-key-box">
                  <code>{newApiKey}</code>
                  <button onClick={copyApiKey} className="copy-btn">
                    {copied ? <Check size={16} /> : <Copy size={16} />}
                  </button>
                </div>
                <button
                  className="btn btn-primary btn-full"
                  onClick={() => { setShowScannerModal(false); setNewApiKey(null); }}
                >
                  Tamam
                </button>
              </div>
            ) : (
              <>
                {formError && <div className="modal-error">{formError}</div>}
                <form onSubmit={handleCreateScanner} className="modal-form">
                  <div className="form-group">
                    <label htmlFor="scanner-name">Tarayıcı Adı *</label>
                    <input
                      id="scanner-name"
                      value={scannerForm.name}
                      onChange={(e) => setScannerForm({ ...scannerForm, name: e.target.value })}
                      required
                      placeholder="Ör: Kütüphane-Scanner-01"
                    />
                  </div>
                  <div className="form-group">
                    <label htmlFor="scanner-area">Alan (Opsiyonel)</label>
                    <select
                      id="scanner-area"
                      value={scannerForm.area_id}
                      onChange={(e) => setScannerForm({ ...scannerForm, area_id: e.target.value })}
                    >
                      <option value="">— Seçilmedi —</option>
                      {areas.map((a) => (
                        <option key={a.id} value={a.id}>{a.name}</option>
                      ))}
                    </select>
                  </div>
                  <button type="submit" className="btn btn-primary btn-full" id="submit-scanner">
                    <Plus size={16} /> Tarayıcı Oluştur
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      )}

      {/* ─── Delete Confirm Modal ─────────────────────── */}
      {deleteConfirm && (
        <div className="modal-overlay" onClick={() => setDeleteConfirm(null)}>
          <div className="modal modal-sm" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Silme Onayı</h3>
              <button className="modal-close" onClick={() => setDeleteConfirm(null)}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <AlertTriangle size={32} className="text-warning" />
              <p>
                <strong>{deleteConfirm.name || `#${deleteConfirm.id}`}</strong>{" "}
                {deleteConfirm.type === "area" ? "alanını" : "tarayıcısını"}{" "}
                silmek istediğinize emin misiniz?
              </p>
            </div>
            <div className="modal-actions">
              <button
                className="btn btn-ghost"
                onClick={() => setDeleteConfirm(null)}
              >
                İptal
              </button>
              <button
                className="btn btn-danger"
                onClick={() =>
                  deleteConfirm.type === "area"
                    ? handleDeleteArea(deleteConfirm.id)
                    : handleDeleteScanner(deleteConfirm.id)
                }
                id="confirm-delete"
              >
                <Trash2 size={16} /> Sil
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
