import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiRequest, clearToken } from '../api/client';

const NAV_ITEMS = [
  { key: 'dashboard', label: 'Genel Bakış' },
  { key: 'analytics', label: 'Yoğunluk Analizi' },
  { key: 'map', label: 'Konum Haritası' },
  { key: 'areas', label: 'Alanlar' },
  { key: 'scanners', label: 'Scannerlar' },
  { key: 'logs', label: 'Bluetooth Logları' },
];

const EMPTY_DATA = {
  dashboard: null,
  areas: [],
  scanners: [],
  liveOccupancy: [],
  heatmap: [],
  logs: [],
};

const INITIAL_AREA_FORM = {
  name: '',
  floor: '',
  capacity: '',
  latitude: '',
  longitude: '',
};

const INITIAL_SCANNER_FORM = {
  name: '',
  area_id: '',
};

function statusLabel(status) {
  const labels = {
    empty: 'Boş',
    low: 'Düşük',
    medium: 'Orta',
    high: 'Yoğun',
    full: 'Dolu',
  };

  return labels[status] || status || 'Bilinmiyor';
}

function statusClass(status) {
  return status || 'empty';
}

function formatDate(value) {
  if (!value) return 'Veri yok';

  try {
    return new Date(value).toLocaleString('tr-TR');
  } catch {
    return value;
  }
}

function formatPercent(value) {
  const number = Number(value || 0);
  return Number.isInteger(number) ? number : number.toFixed(1);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function optionalNumber(value) {
  if (value === '' || value === null || value === undefined) {
    return undefined;
  }

  return Number(value);
}

function sortById(items) {
  return [...items].sort((a, b) => Number(a.id || 0) - Number(b.id || 0));
}

function sortHistory(history) {
  return [...history].sort((a, b) => {
    return new Date(a.recorded_at).getTime() - new Date(b.recorded_at).getTime();
  });
}

function formatHour(value) {
  if (!value) return '--:--';

  try {
    return new Date(value).toLocaleTimeString('tr-TR', {
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return value;
  }
}

function formatCoordinate(value) {
  if (value === null || value === undefined) {
    return '-';
  }

  return Number(value).toFixed(5);
}

export default function DashboardPage({ onLogout }) {
  const [activeView, setActiveView] = useState('dashboard');
  const [health, setHealth] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [areas, setAreas] = useState([]);
  const [scanners, setScanners] = useState([]);
  const [liveOccupancy, setLiveOccupancy] = useState([]);
  const [heatmap, setHeatmap] = useState([]);
  const [logs, setLogs] = useState([]);
  const [endpointState, setEndpointState] = useState({});
  const [loading, setLoading] = useState(true);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState('');
  const [error, setError] = useState('');
  const [historyError, setHistoryError] = useState('');
  const [notice, setNotice] = useState('');
  const [areaForm, setAreaForm] = useState(INITIAL_AREA_FORM);
  const [scannerForm, setScannerForm] = useState(INITIAL_SCANNER_FORM);
  const [createdScanner, setCreatedScanner] = useState(null);
  const [logLimit, setLogLimit] = useState(25);
  const [logAreaFilter, setLogAreaFilter] = useState('');
  const [historyAreaId, setHistoryAreaId] = useState('');
  const [historyHours, setHistoryHours] = useState(24);
  const [history, setHistory] = useState([]);

  const logPath = useMemo(() => {
    const params = new URLSearchParams({ limit: String(logLimit) });

    if (logAreaFilter) {
      params.set('area_id', logAreaFilter);
    }

    return `/api/admin/logs?${params.toString()}`;
  }, [logAreaFilter, logLimit]);

  const endpoints = useMemo(
    () => [
      { key: 'health', label: 'Health', path: '/health', auth: false },
      { key: 'dashboard', label: 'Dashboard', path: '/api/admin/dashboard' },
      { key: 'areas', label: 'Alanlar', path: '/api/areas/' },
      { key: 'scanners', label: 'Scannerlar', path: '/api/admin/scanners' },
      { key: 'liveOccupancy', label: 'Canlı doluluk', path: '/api/occupancy/live' },
      { key: 'heatmap', label: 'Konum verisi', path: '/api/occupancy/heatmap' },
      { key: 'logs', label: 'Loglar', path: logPath },
    ],
    [logPath]
  );

  const areaNameById = useMemo(() => {
    return new Map(areas.map((area) => [area.id, area.name]));
  }, [areas]);

  const activeAreas = useMemo(() => {
    return areas.filter((area) => area.is_active).length;
  }, [areas]);

  const activeScanners = useMemo(() => {
    return scanners.filter((scanner) => scanner.is_active).length;
  }, [scanners]);

  const totalDevices = useMemo(() => {
    return liveOccupancy.reduce((sum, item) => {
      return sum + Number(item.device_count || 0);
    }, 0);
  }, [liveOccupancy]);

  const liveByAreaId = useMemo(() => {
    return new Map(liveOccupancy.map((item) => [item.area_id, item]));
  }, [liveOccupancy]);

  const sortedAreas = useMemo(() => sortById(areas), [areas]);
  const sortedScanners = useMemo(() => sortById(scanners), [scanners]);
  const selectedHistoryAreaId = historyAreaId || sortedAreas[0]?.id || liveOccupancy[0]?.area_id || '';
  const selectedHistoryArea = useMemo(() => {
    const numericId = Number(selectedHistoryAreaId);
    return areas.find((area) => area.id === numericId) || null;
  }, [areas, selectedHistoryAreaId]);

  function getAreaLabel(areaId) {
    if (!areaId) return '-';

    const name = areaNameById.get(areaId);
    return name ? `${name} (#${areaId})` : `Alan #${areaId}`;
  }

  function logout() {
    clearToken();
    onLogout();
  }

  const loadData = useCallback(async ({ silent = false } = {}) => {
    if (!silent) {
      setLoading(true);
    }

    const results = await Promise.allSettled(
      endpoints.map((endpoint) =>
        apiRequest(endpoint.path, {
          auth: endpoint.auth !== false,
        })
      )
    );

    const nextData = { ...EMPTY_DATA };
    const nextEndpointState = {};
    const errors = [];
    let nextHealth = null;

    endpoints.forEach((endpoint, index) => {
      const result = results[index];
      const ok = result.status === 'fulfilled';

      nextEndpointState[endpoint.key] = {
        label: endpoint.label,
        ok,
        message: ok ? 'Hazır' : result.reason?.message || 'İstek başarısız',
      };

      if (!ok) {
        errors.push({
          label: endpoint.label,
          status: result.reason?.status,
          message: result.reason?.message || 'İstek başarısız',
        });
        return;
      }

      if (endpoint.key === 'health') {
        nextHealth = result.value;
        return;
      }

      if (endpoint.key === 'dashboard') {
        nextData.dashboard = result.value;
        return;
      }

      nextData[endpoint.key] = asArray(result.value);
    });

    setHealth(nextHealth);
    setDashboard(nextData.dashboard);
    setAreas(nextData.areas);
    setScanners(nextData.scanners);
    setLiveOccupancy(nextData.liveOccupancy);
    setHeatmap(nextData.heatmap);
    setLogs(nextData.logs);
    setEndpointState(nextEndpointState);

    if (errors.length === 0) {
      setError('');
    } else {
      const hasAuthError = errors.some((item) => item.status === 401 || item.status === 403);
      const message = hasAuthError
        ? 'Admin yetkisi gerekiyor. Giriş yaptığınız kullanıcının admin rolünde olduğundan emin olun.'
        : errors.map((item) => `${item.label}: ${item.message}`).join(' | ');

      setError(message);
    }

    setLoading(false);
  }, [endpoints]);

  useEffect(() => {
    let isActive = true;

    Promise.resolve().then(() => {
      if (isActive) {
        loadData();
      }
    });

    const timer = setInterval(() => {
      loadData({ silent: true });
    }, 10000);

    return () => {
      isActive = false;
      clearInterval(timer);
    };
  }, [loadData]);

  const loadHistory = useCallback(async ({ silent = false } = {}) => {
    if (!selectedHistoryAreaId) {
      setHistory([]);
      setHistoryError('');
      return;
    }

    if (!silent) {
      setHistoryLoading(true);
    }

    try {
      const data = await apiRequest(
        `/api/occupancy/history/${selectedHistoryAreaId}?hours=${historyHours}`
      );

      setHistory(sortHistory(asArray(data)));
      setHistoryError('');
    } catch (err) {
      setHistory([]);
      setHistoryError(err.message);
    } finally {
      setHistoryLoading(false);
    }
  }, [historyHours, selectedHistoryAreaId]);

  useEffect(() => {
    let isActive = true;

    Promise.resolve().then(() => {
      if (isActive) {
        loadHistory();
      }
    });

    return () => {
      isActive = false;
    };
  }, [loadHistory]);

  async function runAction(key, action, successMessage) {
    setActionLoading(key);
    setError('');
    setNotice('');

    try {
      await action();
      setNotice(successMessage);
      await loadData({ silent: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setActionLoading('');
    }
  }

  async function createArea(event) {
    event.preventDefault();

    await runAction(
      'create-area',
      async () => {
        const payload = {
          name: areaForm.name.trim(),
          capacity: Number(areaForm.capacity),
        };
        const floor = optionalNumber(areaForm.floor);
        const latitude = optionalNumber(areaForm.latitude);
        const longitude = optionalNumber(areaForm.longitude);

        if (floor !== undefined) payload.floor = floor;
        if (latitude !== undefined) payload.latitude = latitude;
        if (longitude !== undefined) payload.longitude = longitude;

        await apiRequest('/api/areas/', {
          method: 'POST',
          body: JSON.stringify(payload),
        });

        setAreaForm(INITIAL_AREA_FORM);
      },
      'Alan oluşturuldu.'
    );
  }

  async function toggleArea(areaId) {
    await runAction(
      `toggle-area-${areaId}`,
      async () => {
        await apiRequest(`/api/areas/${areaId}/toggle-active`, {
          method: 'PATCH',
        });
      },
      'Alan durumu güncellendi.'
    );
  }

  async function deleteArea(areaId) {
    if (!window.confirm(`Alan #${areaId} silinsin mi?`)) {
      return;
    }

    await runAction(
      `delete-area-${areaId}`,
      async () => {
        await apiRequest(`/api/areas/${areaId}`, {
          method: 'DELETE',
        });
      },
      'Alan silindi.'
    );
  }

  async function createScanner(event) {
    event.preventDefault();

    await runAction(
      'create-scanner',
      async () => {
        const payload = {
          name: scannerForm.name.trim(),
        };

        if (scannerForm.area_id) {
          payload.area_id = Number(scannerForm.area_id);
        }

        const response = await apiRequest('/api/admin/scanners', {
          method: 'POST',
          body: JSON.stringify(payload),
        });

        setCreatedScanner(response);
        setScannerForm(INITIAL_SCANNER_FORM);
      },
      'Scanner oluşturuldu. API anahtarı yalnızca bir kez gösterilir.'
    );
  }

  async function deleteScanner(scannerId) {
    if (!window.confirm(`Scanner #${scannerId} silinsin mi?`)) {
      return;
    }

    await runAction(
      `delete-scanner-${scannerId}`,
      async () => {
        await apiRequest(`/api/admin/scanners/${scannerId}`, {
          method: 'DELETE',
        });
      },
      'Scanner silindi.'
    );
  }

  const currentTitle = NAV_ITEMS.find((item) => item.key === activeView)?.label || 'Genel Bakış';

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="logo-mark">R</div>
          <div>
            <strong>Ruhan Admin</strong>
            <span>Campus Control</span>
          </div>
        </div>

        <nav className="sidebar-nav" aria-label="Admin navigasyonu">
          {NAV_ITEMS.map((item) => (
            <button
              className={activeView === item.key ? 'active' : ''}
              key={item.key}
              type="button"
              onClick={() => setActiveView(item.key)}
            >
              {item.label}
            </button>
          ))}
        </nav>

        <div className="sidebar-status">
          <span>Backend</span>
          <strong className={health?.status === 'ok' ? 'online' : 'offline'}>
            {health?.status === 'ok' ? 'Online' : 'Offline'}
          </strong>
          <p>{health?.app || 'API bağlantısı kontrol ediliyor'}</p>
        </div>
      </aside>

      <section className="content">
        <header className="topbar">
          <div>
            <p className="eyebrow">Admin Panel</p>
            <h1>{currentTitle}</h1>
          </div>

          <div className="topbar-actions">
            <button className="ghost-btn" type="button" onClick={() => loadData()}>
              Yenile
            </button>
            <button className="ghost-btn danger" type="button" onClick={logout}>
              Çıkış
            </button>
          </div>
        </header>

        {error && <div className="alert error">{error}</div>}
        {notice && <div className="alert success">{notice}</div>}
        {loading && <div className="loading-panel">Backend verileri yükleniyor...</div>}

        {activeView === 'dashboard' && (
          <DashboardView
            activeAreas={activeAreas}
            activeScanners={activeScanners}
            areas={areas}
            dashboard={dashboard}
            endpointState={endpointState}
            getAreaLabel={getAreaLabel}
            heatmap={heatmap}
            history={history}
            historyError={historyError}
            historyHours={historyHours}
            historyLoading={historyLoading}
            health={health}
            liveOccupancy={liveOccupancy}
            logs={logs}
            onRefreshHistory={() => loadHistory()}
            onSetHistoryAreaId={setHistoryAreaId}
            onSetHistoryHours={setHistoryHours}
            selectedHistoryArea={selectedHistoryArea}
            selectedHistoryAreaId={selectedHistoryAreaId}
            scanners={scanners}
            sortedAreas={sortedAreas}
            totalDevices={totalDevices}
          />
        )}

        {activeView === 'analytics' && (
          <AnalyticsView
            areas={sortedAreas}
            history={history}
            historyError={historyError}
            historyHours={historyHours}
            historyLoading={historyLoading}
            liveOccupancy={liveOccupancy}
            onRefreshHistory={() => loadHistory()}
            onSetHistoryAreaId={setHistoryAreaId}
            onSetHistoryHours={setHistoryHours}
            selectedHistoryArea={selectedHistoryArea}
            selectedHistoryAreaId={selectedHistoryAreaId}
          />
        )}

        {activeView === 'map' && (
          <LocationView
            heatmap={heatmap}
            liveOccupancy={liveOccupancy}
            areas={sortedAreas}
          />
        )}

        {activeView === 'areas' && (
          <AreasView
            actionLoading={actionLoading}
            areaForm={areaForm}
            liveByAreaId={liveByAreaId}
            onCreateArea={createArea}
            onDeleteArea={deleteArea}
            onSetAreaForm={setAreaForm}
            onToggleArea={toggleArea}
            sortedAreas={sortedAreas}
          />
        )}

        {activeView === 'scanners' && (
          <ScannersView
            actionLoading={actionLoading}
            areas={sortedAreas}
            createdScanner={createdScanner}
            getAreaLabel={getAreaLabel}
            onCreateScanner={createScanner}
            onDeleteScanner={deleteScanner}
            onDismissCreatedScanner={() => setCreatedScanner(null)}
            onSetScannerForm={setScannerForm}
            scannerForm={scannerForm}
            sortedScanners={sortedScanners}
          />
        )}

        {activeView === 'logs' && (
          <LogsView
            areas={sortedAreas}
            logs={logs}
            logAreaFilter={logAreaFilter}
            logLimit={logLimit}
            onRefresh={() => loadData()}
            onSetLogAreaFilter={setLogAreaFilter}
            onSetLogLimit={setLogLimit}
          />
        )}
      </section>
    </main>
  );
}

function DashboardView({
  activeAreas,
  activeScanners,
  areas,
  dashboard,
  endpointState,
  getAreaLabel,
  heatmap,
  history,
  historyError,
  historyHours,
  historyLoading,
  health,
  liveOccupancy,
  logs,
  onRefreshHistory,
  onSetHistoryAreaId,
  onSetHistoryHours,
  selectedHistoryArea,
  selectedHistoryAreaId,
  scanners,
  sortedAreas,
  totalDevices,
}) {
  const cards = [
    {
      title: 'Alan Sayısı',
      value: dashboard?.total_areas ?? areas.length,
      meta: `${dashboard?.active_areas ?? activeAreas} aktif`,
    },
    {
      title: 'Scanner Sayısı',
      value: scanners.length,
      meta: `${activeScanners} aktif`,
    },
    {
      title: 'Canlı Tekil Cihaz',
      value: totalDevices,
      meta: 'Son canlı ölçümlerin toplamı',
    },
    {
      title: 'Backend Durumu',
      value: health?.status === 'ok' ? 'Online' : 'Offline',
      meta: health?.app || 'API bağlantısı bekleniyor',
    },
  ];

  return (
    <>
      <section className="summary-grid">
        {cards.map((card) => (
          <article className="stat-card" key={card.title}>
            <span>{card.title}</span>
            <strong>{card.value}</strong>
            <p>{card.meta}</p>
          </article>
        ))}
      </section>

      <section className="layout-grid">
        <article className="panel panel-wide">
          <PanelTitle
            eyebrow="Canlı doluluk"
            title="Alan Yoğunlukları"
            description="/api/occupancy/live verisi"
          />

          <div className="density-list">
            {liveOccupancy.length === 0 && (
              <EmptyState title="Henüz canlı doluluk kaydı yok" />
            )}

            {liveOccupancy.map((area) => (
              <DensityRow area={area} key={area.area_id} />
            ))}
          </div>
        </article>

        <article className="panel">
          <PanelTitle eyebrow="Sistem" title="Operasyon Özeti" />

          <div className="info-stack">
            <InfoLine label="Ortalama doluluk" value={`%${formatPercent(dashboard?.avg_occupancy)}`} />
            <InfoLine label="En yoğun alan" value={dashboard?.busiest_area?.area_name || 'Veri yok'} />
            <InfoLine label="En sakin alan" value={dashboard?.emptiest_area?.area_name || 'Veri yok'} />
            <InfoLine label="Toplam kullanıcı" value={dashboard?.total_users ?? 0} />
          </div>

          <div className="endpoint-list">
            {Object.values(endpointState).map((state) => (
              <div className="endpoint-row" key={state.label}>
                <span>{state.label}</span>
                <strong className={state.ok ? 'online' : 'offline'}>
                  {state.ok ? 'OK' : 'Hata'}
                </strong>
              </div>
            ))}
          </div>
        </article>
      </section>

      <section className="layout-grid analytics-preview-grid">
        <article className="panel panel-wide">
          <div className="panel-toolbar">
            <PanelTitle
              eyebrow="Zaman analizi"
              title="Saatlik Doluluk Eğilimi"
              description="/api/occupancy/history/{area_id} verisi"
            />
            <HistoryControls
              areas={sortedAreas}
              historyHours={historyHours}
              onRefreshHistory={onRefreshHistory}
              onSetHistoryAreaId={onSetHistoryAreaId}
              onSetHistoryHours={onSetHistoryHours}
              selectedHistoryAreaId={selectedHistoryAreaId}
            />
          </div>

          {historyError && <div className="inline-error">{historyError}</div>}
          <HistoryChart
            history={history}
            loading={historyLoading}
            selectedArea={selectedHistoryArea}
          />
        </article>

        <article className="panel">
          <PanelTitle
            eyebrow="Konum"
            title="Canlı Alan Haritası"
            description="/api/occupancy/heatmap verisi"
          />
          <CampusMap heatmap={heatmap} liveOccupancy={liveOccupancy} compact />
        </article>
      </section>

      <section className="layout-grid lower-grid">
        <article className="panel">
          <PanelTitle eyebrow="Scanner" title="Son Durum" />
          <ScannerTable scanners={scanners.slice(0, 6)} getAreaLabel={getAreaLabel} compact />
        </article>

        <article className="panel">
          <PanelTitle eyebrow="Log" title="Son Kayıtlar" />
          <LogList logs={logs.slice(0, 6)} />
        </article>
      </section>
    </>
  );
}

function AnalyticsView({
  areas,
  history,
  historyError,
  historyHours,
  historyLoading,
  liveOccupancy,
  onRefreshHistory,
  onSetHistoryAreaId,
  onSetHistoryHours,
  selectedHistoryArea,
  selectedHistoryAreaId,
}) {
  return (
    <section className="analytics-page">
      <article className="panel">
        <div className="panel-toolbar">
          <PanelTitle
            eyebrow="Zaman serisi"
            title="Saat Bazlı Yoğunluk"
            description="Seçilen alanın geçmiş doluluk kayıtları"
          />
          <HistoryControls
            areas={areas}
            historyHours={historyHours}
            onRefreshHistory={onRefreshHistory}
            onSetHistoryAreaId={onSetHistoryAreaId}
            onSetHistoryHours={onSetHistoryHours}
            selectedHistoryAreaId={selectedHistoryAreaId}
          />
        </div>

        {historyError && <div className="inline-error">{historyError}</div>}

        <HistoryChart
          history={history}
          loading={historyLoading}
          selectedArea={selectedHistoryArea}
        />
      </article>

      <section className="layout-grid lower-grid">
        <article className="panel">
          <PanelTitle
            eyebrow="Saat dağılımı"
            title="Hangi Saatlerde Yoğun?"
            description="Kayıtların saatlere göre ortalaması"
          />
          <HourlyBreakdown history={history} />
        </article>

        <article className="panel">
          <PanelTitle
            eyebrow="Canlı karşılaştırma"
            title="Alanların Şu Anki Durumu"
            description="/api/occupancy/live"
          />
          <div className="density-list">
            {liveOccupancy.length === 0 && <EmptyState title="Canlı doluluk verisi yok" />}
            {liveOccupancy.map((area) => (
              <DensityRow area={area} key={area.area_id} />
            ))}
          </div>
        </article>
      </section>
    </section>
  );
}

function LocationView({ areas, heatmap, liveOccupancy }) {
  return (
    <section className="layout-grid">
      <article className="panel panel-wide">
        <PanelTitle
          eyebrow="Kampüs konum görünümü"
          title="Alan Merkezli Canlı Yoğunluk"
          description="Backend alan merkezi koordinatı döndürürse noktalar gerçek enlem/boylamla yerleşir"
        />
        <CampusMap heatmap={heatmap} liveOccupancy={liveOccupancy} />
      </article>

      <article className="panel">
        <PanelTitle
          eyebrow="Konum kayıtları"
          title="Alan Noktaları"
          description="Bireysel Bluetooth cihaz koordinatı backend tarafından sağlanmıyor"
        />
        <LocationPointList areas={areas} heatmap={heatmap} liveOccupancy={liveOccupancy} />
      </article>
    </section>
  );
}

function AreasView({
  actionLoading,
  areaForm,
  liveByAreaId,
  onCreateArea,
  onDeleteArea,
  onSetAreaForm,
  onToggleArea,
  sortedAreas,
}) {
  return (
    <section className="page-grid">
      <article className="panel">
        <PanelTitle
          eyebrow="Alan yönetimi"
          title="Yeni Alan"
          description="POST /api/areas/"
        />

        <form className="stack-form" onSubmit={onCreateArea}>
          <label>
            Alan adı
            <input
              required
              value={areaForm.name}
              onChange={(event) => onSetAreaForm({ ...areaForm, name: event.target.value })}
              placeholder="Örn. Kütüphane"
            />
          </label>

          <div className="form-row">
            <label>
              Kapasite
              <input
                min="1"
                required
                type="number"
                value={areaForm.capacity}
                onChange={(event) => onSetAreaForm({ ...areaForm, capacity: event.target.value })}
                placeholder="100"
              />
            </label>

            <label>
              Kat
              <input
                type="number"
                value={areaForm.floor}
                onChange={(event) => onSetAreaForm({ ...areaForm, floor: event.target.value })}
                placeholder="0"
              />
            </label>
          </div>

          <div className="form-row">
            <label>
              Enlem
              <input
                type="number"
                step="any"
                value={areaForm.latitude}
                onChange={(event) => onSetAreaForm({ ...areaForm, latitude: event.target.value })}
                placeholder="Opsiyonel"
              />
            </label>

            <label>
              Boylam
              <input
                type="number"
                step="any"
                value={areaForm.longitude}
                onChange={(event) => onSetAreaForm({ ...areaForm, longitude: event.target.value })}
                placeholder="Opsiyonel"
              />
            </label>
          </div>

          <button className="primary-btn" disabled={actionLoading === 'create-area'} type="submit">
            {actionLoading === 'create-area' ? 'Kaydediliyor...' : 'Alan Oluştur'}
          </button>
        </form>
      </article>

      <article className="panel panel-wide">
        <PanelTitle
          eyebrow="Kayıtlı alanlar"
          title="Alan Listesi"
          description="GET /api/areas/"
        />

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Alan</th>
                <th>Kapasite</th>
                <th>Canlı Cihaz</th>
                <th>Doluluk</th>
                <th>Durum</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              {sortedAreas.length === 0 && (
                <tr>
                  <td colSpan="7">Kayıtlı alan yok.</td>
                </tr>
              )}

              {sortedAreas.map((area) => {
                const live = liveByAreaId.get(area.id);

                return (
                  <tr key={area.id}>
                    <td>{area.id}</td>
                    <td>
                      <strong>{area.name}</strong>
                      <small>Kat: {area.floor ?? '-'}</small>
                    </td>
                    <td>{area.capacity}</td>
                    <td>{live?.device_count ?? 0}</td>
                    <td>%{formatPercent(live?.occupancy_pct)}</td>
                    <td>
                      <span className={`status ${area.is_active ? 'low' : 'empty'}`}>
                        {area.is_active ? 'Aktif' : 'Pasif'}
                      </span>
                    </td>
                    <td>
                      <div className="row-actions">
                        <button
                          className="text-btn"
                          disabled={actionLoading === `toggle-area-${area.id}`}
                          type="button"
                          onClick={() => onToggleArea(area.id)}
                        >
                          {area.is_active ? 'Pasifleştir' : 'Aktifleştir'}
                        </button>
                        <button
                          className="text-btn danger"
                          disabled={actionLoading === `delete-area-${area.id}`}
                          type="button"
                          onClick={() => onDeleteArea(area.id)}
                        >
                          Sil
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </article>
    </section>
  );
}

function ScannersView({
  actionLoading,
  areas,
  createdScanner,
  getAreaLabel,
  onCreateScanner,
  onDeleteScanner,
  onDismissCreatedScanner,
  onSetScannerForm,
  scannerForm,
  sortedScanners,
}) {
  return (
    <section className="page-grid">
      <article className="panel">
        <PanelTitle
          eyebrow="Scanner yönetimi"
          title="Yeni Scanner"
          description="POST /api/admin/scanners"
        />

        <form className="stack-form" onSubmit={onCreateScanner}>
          <label>
            Scanner adı
            <input
              required
              value={scannerForm.name}
              onChange={(event) => onSetScannerForm({ ...scannerForm, name: event.target.value })}
              placeholder="Örn. Library Scanner"
            />
          </label>

          <label>
            Bağlı alan
            <select
              value={scannerForm.area_id}
              onChange={(event) => onSetScannerForm({ ...scannerForm, area_id: event.target.value })}
            >
              <option value="">Alan seçilmedi</option>
              {areas.map((area) => (
                <option key={area.id} value={area.id}>
                  {area.name} #{area.id}
                </option>
              ))}
            </select>
          </label>

          <button className="primary-btn" disabled={actionLoading === 'create-scanner'} type="submit">
            {actionLoading === 'create-scanner' ? 'Kaydediliyor...' : 'Scanner Oluştur'}
          </button>
        </form>

        {createdScanner?.api_key && (
          <div className="secret-box">
            <button className="text-btn" type="button" onClick={onDismissCreatedScanner}>
              Kapat
            </button>
            <span>API anahtarı yalnızca bir kez gösterilir</span>
            <code>{createdScanner.api_key}</code>
          </div>
        )}
      </article>

      <article className="panel panel-wide">
        <PanelTitle
          eyebrow="Kayıtlı scannerlar"
          title="Scanner Listesi"
          description="GET /api/admin/scanners"
        />

        <ScannerTable
          actionLoading={actionLoading}
          getAreaLabel={getAreaLabel}
          onDeleteScanner={onDeleteScanner}
          scanners={sortedScanners}
        />
      </article>
    </section>
  );
}

function LogsView({
  areas,
  logs,
  logAreaFilter,
  logLimit,
  onRefresh,
  onSetLogAreaFilter,
  onSetLogLimit,
}) {
  return (
    <article className="panel">
      <div className="panel-toolbar">
        <PanelTitle
          eyebrow="Bluetooth logları"
          title="Doluluk Kayıtları"
          description="GET /api/admin/logs"
        />

        <div className="toolbar-controls">
          <select value={logAreaFilter} onChange={(event) => onSetLogAreaFilter(event.target.value)}>
            <option value="">Tüm alanlar</option>
            {areas.map((area) => (
              <option key={area.id} value={area.id}>
                {area.name} #{area.id}
              </option>
            ))}
          </select>

          <select value={logLimit} onChange={(event) => onSetLogLimit(Number(event.target.value))}>
            <option value={10}>10 kayıt</option>
            <option value={25}>25 kayıt</option>
            <option value={50}>50 kayıt</option>
            <option value={100}>100 kayıt</option>
          </select>

          <button className="ghost-btn" type="button" onClick={onRefresh}>
            Yenile
          </button>
        </div>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Zaman</th>
              <th>Cihaz Sayısı</th>
              <th>Doluluk</th>
              <th>Durum</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 && (
              <tr>
                <td colSpan="4">Henüz doluluk logu yok.</td>
              </tr>
            )}

            {logs.map((log, index) => (
              <tr key={`${log.recorded_at}-${index}`}>
                <td>{formatDate(log.recorded_at)}</td>
                <td>{log.device_count ?? 0}</td>
                <td>%{formatPercent(log.occupancy_pct)}</td>
                <td>
                  <span className={`status ${statusClass(log.status)}`}>
                    {statusLabel(log.status)}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </article>
  );
}

function DensityRow({ area }) {
  return (
    <div className="density-row">
      <div>
        <strong>{area.area_name}</strong>
        <span>Alan ID: {area.area_id}</span>
      </div>

      <div className="bar">
        <i style={{ width: `${Math.min(area.occupancy_pct || 0, 100)}%` }} />
      </div>

      <div className={`status ${statusClass(area.status)}`}>
        {statusLabel(area.status)}
      </div>

      <div className="metric-pair">
        <strong>{area.device_count ?? 0}</strong>
        <span>%{formatPercent(area.occupancy_pct)}</span>
      </div>
    </div>
  );
}

function HistoryControls({
  areas,
  historyHours,
  onRefreshHistory,
  onSetHistoryAreaId,
  onSetHistoryHours,
  selectedHistoryAreaId,
}) {
  return (
    <div className="toolbar-controls">
      <select
        value={selectedHistoryAreaId || ''}
        onChange={(event) => onSetHistoryAreaId(event.target.value)}
      >
        {areas.length === 0 && <option value="">Alan yok</option>}
        {areas.map((area) => (
          <option key={area.id} value={area.id}>
            {area.name} #{area.id}
          </option>
        ))}
      </select>

      <select
        value={historyHours}
        onChange={(event) => onSetHistoryHours(Number(event.target.value))}
      >
        <option value={6}>Son 6 saat</option>
        <option value={12}>Son 12 saat</option>
        <option value={24}>Son 24 saat</option>
        <option value={72}>Son 3 gün</option>
        <option value={168}>Son 7 gün</option>
      </select>

      <button className="ghost-btn" type="button" onClick={onRefreshHistory}>
        Grafiği Yenile
      </button>
    </div>
  );
}

function HistoryChart({ history, loading, selectedArea }) {
  const points = sortHistory(history);
  const width = 720;
  const height = 220;
  const padding = 18;
  const chartWidth = width - padding * 2;
  const chartHeight = height - padding * 2;
  const linePoints = points.map((item, index) => {
    const x = padding + (points.length === 1 ? chartWidth / 2 : (index / (points.length - 1)) * chartWidth);
    const y = padding + chartHeight - (Math.min(Number(item.occupancy_pct || 0), 100) / 100) * chartHeight;
    return { ...item, x, y };
  });
  const path = linePoints.map((point) => `${point.x},${point.y}`).join(' ');
  const latest = points[points.length - 1];
  const peak = points.reduce((max, item) => {
    return Number(item.occupancy_pct || 0) > Number(max?.occupancy_pct || 0) ? item : max;
  }, null);

  if (loading) {
    return <div className="chart-empty">Grafik verisi yükleniyor...</div>;
  }

  if (!selectedArea) {
    return <EmptyState title="Grafik için önce alan oluşturulmalı" />;
  }

  if (points.length === 0) {
    return <EmptyState title="Seçilen alan için geçmiş doluluk kaydı yok" />;
  }

  return (
    <div className="history-chart">
      <div className="chart-summary">
        <InfoLine label="Alan" value={selectedArea.name} />
        <InfoLine label="Son kayıt" value={`${latest.device_count ?? 0} cihaz / %${formatPercent(latest.occupancy_pct)}`} />
        <InfoLine label="Zirve" value={`${formatHour(peak?.recorded_at)} / %${formatPercent(peak?.occupancy_pct)}`} />
      </div>

      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Saatlik doluluk grafiği">
        <line x1={padding} x2={width - padding} y1={height - padding} y2={height - padding} />
        <line x1={padding} x2={padding} y1={padding} y2={height - padding} />
        <polyline points={path} />
        {linePoints.map((point, index) => (
          <g key={`${point.recorded_at}-${index}`}>
            <circle cx={point.x} cy={point.y} r="5" />
            <title>
              {formatDate(point.recorded_at)} - {point.device_count} cihaz - %{formatPercent(point.occupancy_pct)}
            </title>
          </g>
        ))}
      </svg>

      <div className="chart-axis">
        <span>{formatHour(points[0]?.recorded_at)}</span>
        <span>{formatHour(latest?.recorded_at)}</span>
      </div>
    </div>
  );
}

function HourlyBreakdown({ history }) {
  const buckets = sortHistory(history).reduce((acc, item) => {
    const date = new Date(item.recorded_at);
    const hour = Number.isNaN(date.getTime()) ? '--' : date.getHours().toString().padStart(2, '0');

    if (!acc[hour]) {
      acc[hour] = {
        hour,
        count: 0,
        deviceTotal: 0,
        occupancyTotal: 0,
      };
    }

    acc[hour].count += 1;
    acc[hour].deviceTotal += Number(item.device_count || 0);
    acc[hour].occupancyTotal += Number(item.occupancy_pct || 0);
    return acc;
  }, {});

  const rows = Object.values(buckets).sort((a, b) => String(a.hour).localeCompare(String(b.hour)));

  if (rows.length === 0) {
    return <EmptyState title="Saatlik dağılım için kayıt yok" />;
  }

  return (
    <div className="hour-bars">
      {rows.map((row) => {
        const avgOccupancy = row.occupancyTotal / row.count;
        const avgDevices = row.deviceTotal / row.count;

        return (
          <div className="hour-row" key={row.hour}>
            <span>{row.hour}:00</span>
            <div className="bar">
              <i style={{ width: `${Math.min(avgOccupancy, 100)}%` }} />
            </div>
            <strong>%{formatPercent(avgOccupancy)}</strong>
            <small>{formatPercent(avgDevices)} cihaz</small>
          </div>
        );
      })}
    </div>
  );
}

function CampusMap({ compact = false, heatmap, liveOccupancy }) {
  const liveById = new Map(liveOccupancy.map((item) => [item.area_id, item]));
  const points = heatmap.map((entry, index) => ({
    ...entry,
    index,
    live: liveById.get(entry.area_id),
  }));
  const located = points.filter((point) => point.latitude !== null && point.longitude !== null);
  const hasCoordinates = located.length > 0;
  const latitudes = located.map((point) => Number(point.latitude));
  const longitudes = located.map((point) => Number(point.longitude));
  const minLat = Math.min(...latitudes);
  const maxLat = Math.max(...latitudes);
  const minLon = Math.min(...longitudes);
  const maxLon = Math.max(...longitudes);

  function getPosition(point) {
    if (hasCoordinates && point.latitude !== null && point.longitude !== null) {
      const latRange = maxLat - minLat || 1;
      const lonRange = maxLon - minLon || 1;
      return {
        left: 8 + ((Number(point.longitude) - minLon) / lonRange) * 84,
        top: 8 + (1 - (Number(point.latitude) - minLat) / latRange) * 84,
      };
    }

    const columns = compact ? 2 : 3;
    const col = point.index % columns;
    const row = Math.floor(point.index / columns);
    return {
      left: 16 + col * (72 / Math.max(columns - 1, 1)),
      top: 22 + row * 24,
    };
  }

  if (points.length === 0) {
    return <EmptyState title="Konum haritası için alan verisi yok" />;
  }

  return (
    <div className={`campus-map ${compact ? 'compact' : ''}`}>
      <div className="map-grid" aria-label="Canlı alan konumları">
        {points.map((point) => {
          const position = getPosition(point);
          const occupancy = point.live?.occupancy_pct ?? point.occupancy_pct ?? 0;
          const devices = point.live?.device_count ?? 0;

          return (
            <div
              className={`map-point ${statusClass(point.status)}`}
              key={point.area_id}
              style={{
                left: `${position.left}%`,
                top: `${position.top}%`,
                '--size': `${Math.max(18, Math.min(46, 18 + Number(occupancy) / 2))}px`,
              }}
            >
              <strong>{formatPercent(occupancy)}%</strong>
              <span>{point.area_name}</span>
              <small>{devices} cihaz</small>
            </div>
          );
        })}
      </div>

      <p className="map-note">
        {hasCoordinates
          ? 'Noktalar alan koordinatlarına göre yerleştirildi.'
          : 'Alanlarda koordinat olmadığı için noktalar operasyon görünümü olarak dizildi.'}
      </p>
    </div>
  );
}

function LocationPointList({ areas, heatmap, liveOccupancy }) {
  const liveById = new Map(liveOccupancy.map((item) => [item.area_id, item]));

  if (heatmap.length === 0 && areas.length === 0) {
    return <EmptyState title="Kayıtlı alan yok" />;
  }

  return (
    <div className="location-list">
      {(heatmap.length > 0 ? heatmap : areas).map((item) => {
        const areaId = item.area_id ?? item.id;
        const live = liveById.get(areaId);
        const occupancy = live?.occupancy_pct ?? item.occupancy_pct ?? 0;
        const status = live?.status ?? item.status ?? 'empty';

        return (
          <div className="location-row" key={areaId}>
            <div>
              <strong>{item.area_name ?? item.name}</strong>
              <span>Alan ID: {areaId}</span>
              <span>
                Konum: {formatCoordinate(item.latitude)}, {formatCoordinate(item.longitude)}
              </span>
            </div>
            <div>
              <span className={`status ${statusClass(status)}`}>{statusLabel(status)}</span>
              <small>%{formatPercent(occupancy)}</small>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function ScannerTable({
  actionLoading = '',
  compact = false,
  getAreaLabel,
  onDeleteScanner,
  scanners,
}) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Ad</th>
            <th>Alan</th>
            <th>Durum</th>
            <th>Son Görülme</th>
            {!compact && <th>İşlem</th>}
          </tr>
        </thead>
        <tbody>
          {scanners.length === 0 && (
            <tr>
              <td colSpan={compact ? '5' : '6'}>Kayıtlı scanner yok.</td>
            </tr>
          )}

          {scanners.map((scanner) => (
            <tr key={scanner.id}>
              <td>{scanner.id}</td>
              <td>{scanner.name || '-'}</td>
              <td>{getAreaLabel(scanner.area_id)}</td>
              <td>
                <span className={`status ${scanner.is_active ? 'low' : 'empty'}`}>
                  {scanner.is_active ? 'Aktif' : 'Pasif'}
                </span>
              </td>
              <td>{formatDate(scanner.last_seen)}</td>
              {!compact && (
                <td>
                  <button
                    className="text-btn danger"
                    disabled={actionLoading === `delete-scanner-${scanner.id}`}
                    type="button"
                    onClick={() => onDeleteScanner(scanner.id)}
                  >
                    Sil
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function LogList({ logs }) {
  return (
    <div className="log-list">
      {logs.length === 0 && <EmptyState title="Henüz doluluk logu yok" />}

      {logs.map((log, index) => (
        <div className="log-row" key={`${log.recorded_at}-${index}`}>
          <div>
            <strong>{log.device_count ?? 0} cihaz</strong>
            <span>{formatDate(log.recorded_at)}</span>
          </div>

          <div className={`status ${statusClass(log.status)}`}>
            {statusLabel(log.status)}
          </div>
        </div>
      ))}
    </div>
  );
}

function PanelTitle({ description, eyebrow, title }) {
  return (
    <div className="panel-title">
      {eyebrow && <span>{eyebrow}</span>}
      <h2>{title}</h2>
      {description && <p>{description}</p>}
    </div>
  );
}

function InfoLine({ label, value }) {
  return (
    <div className="info-line">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function EmptyState({ title }) {
  return <div className="empty-state">{title}</div>;
}
