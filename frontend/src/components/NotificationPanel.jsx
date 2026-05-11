import React, { useState } from 'react';
import { api } from '../services/api';

// Demo FCM token (in a real app, retrieved from Firebase SDK)
const DEMO_FCM_TOKEN = 'demo-fcm-token-campus-pulse-2024';

export default function NotificationPanel({ areas }) {
  const [selectedAreaId, setSelectedAreaId] = useState('');
  const [threshold, setThreshold]           = useState(80);
  const [direction, setDirection]           = useState('above');
  const [subscriptions, setSubscriptions]   = useState([]);
  const [toast, setToast]                   = useState(null);
  const [isLoading, setIsLoading]           = useState(false);

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleSubscribe = async () => {
    if (!selectedAreaId) return showToast('Lütfen bir alan seçin', 'error');
    setIsLoading(true);
    try {
      const result = await api.subscribe({
        fcmToken:     DEMO_FCM_TOKEN,
        areaId:       parseInt(selectedAreaId),
        thresholdPct: threshold,
        direction,
      });
      setSubscriptions(prev => [...prev.filter(s => s.id !== result.id), result]);
      showToast(`✅ "${result.area_name}" için bildirim ayarlandı`);
    } catch (e) {
      showToast(`❌ Hata: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnsubscribe = async (id) => {
    try {
      await api.unsubscribe(id);
      setSubscriptions(prev => prev.filter(s => s.id !== id));
      showToast('🗑️ Abonelik iptal edildi');
    } catch (e) {
      showToast(`❌ ${e.message}`, 'error');
    }
  };

  const directionLabel = direction === 'above' ? 'üzerine çıkınca' : 'altına düşünce';

  const selectedArea = areas?.find(a => (a.area_id || a.id) === parseInt(selectedAreaId));

  return (
    <div className="page-container">
      <div className="page-header" style={{ padding: 0, marginBottom: '2rem' }}>
        <div className="page-header-info">
          <h1>🔔 Bildirim Tercihleri</h1>
          <p>Belirli bir doluluk eşiğini aştığında push bildirim al</p>
        </div>
      </div>

      {/* Form card */}
      <div className="glass-card" style={{ padding: '2rem', marginBottom: '2rem', maxWidth: 560 }}>
        <h3 style={{ marginBottom: '1.5rem', color: 'var(--text-primary)' }}>Yeni Bildirim Ekle</h3>

        {/* Area select */}
        <div className="form-group" style={{ marginBottom: '1.25rem' }}>
          <label className="form-label">Alan</label>
          <select
            id="area-select"
            className="form-select"
            value={selectedAreaId}
            onChange={e => setSelectedAreaId(e.target.value)}
          >
            <option value="">Alan seçin...</option>
            {areas?.map(a => (
              <option key={a.area_id || a.id} value={a.area_id || a.id}>
                {a.icon} {a.area_name || a.name} ({a.building})
              </option>
            ))}
          </select>
        </div>

        {/* Direction */}
        <div className="form-group" style={{ marginBottom: '1.25rem' }}>
          <label className="form-label">Bildirim Yönü</label>
          <div style={{ display: 'flex', gap: '0.75rem' }}>
            {[
              { val: 'above', label: '⬆️ Eşik aşılınca' },
              { val: 'below', label: '⬇️ Eşik altına düşünce' },
            ].map(opt => (
              <button
                key={opt.val}
                className={`filter-tab ${direction === opt.val ? 'active' : ''}`}
                onClick={() => setDirection(opt.val)}
                style={{ flex: 1, justifyContent: 'center', padding: '0.6rem' }}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Threshold slider */}
        <div className="form-group" style={{ marginBottom: '1.75rem' }}>
          <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span>Eşik Değeri</span>
            <span style={{ color: 'var(--accent-blue)', fontWeight: 700 }}>%{threshold}</span>
          </label>
          <input
            type="range"
            min={10} max={100} step={5}
            value={threshold}
            onChange={e => setThreshold(parseInt(e.target.value))}
          />
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
            {selectedArea ? (
              <>
                <strong style={{ color: 'var(--text-secondary)' }}>{selectedArea.icon} {selectedArea.area_name}</strong>{' '}
                doluluk oranı <strong>%{threshold}</strong> {directionLabel} bildirim alacaksın.
              </>
            ) : (
              'Alan seçildikten sonra önizleme görünecek.'
            )}
          </div>
        </div>

        <button
          id="btn-subscribe"
          className="btn btn-primary"
          style={{ width: '100%', justifyContent: 'center', padding: '0.75rem' }}
          onClick={handleSubscribe}
          disabled={isLoading || !selectedAreaId}
        >
          {isLoading ? '⏳ Kaydediliyor...' : '🔔 Bildirim Ekle'}
        </button>
      </div>

      {/* Active subscriptions */}
      {subscriptions.length > 0 && (
        <div>
          <h3 style={{ marginBottom: '1rem', color: 'var(--text-primary)' }}>
            Aktif Bildirimler ({subscriptions.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {subscriptions.map(sub => (
              <div key={sub.id} className="notification-card">
                <div>
                  <div style={{ fontWeight: 600, marginBottom: '0.25rem' }}>{sub.area_name}</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    {sub.direction === 'above' ? '⬆️' : '⬇️'} Eşik: %{sub.threshold_pct}
                    {' '}{sub.direction === 'above' ? 'üzerine çıkınca' : 'altına düşünce'}
                  </div>
                </div>
                <button
                  className="btn btn-ghost"
                  style={{ padding: '0.4rem 0.85rem', fontSize: '0.8rem' }}
                  onClick={() => handleUnsubscribe(sub.id)}
                >
                  🗑️ İptal
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* FCM info */}
      <div style={{
        marginTop: '2rem',
        padding: '1rem 1.25rem',
        background: 'rgba(59,130,246,0.07)',
        border: '1px solid rgba(59,130,246,0.15)',
        borderRadius: 'var(--radius-md)',
        fontSize: '0.8rem',
        color: 'var(--text-secondary)',
      }}>
        <strong style={{ color: 'var(--accent-blue)' }}>📱 Firebase Cloud Messaging (FCM)</strong>
        <p style={{ marginTop: '0.35rem' }}>
          Gerçek push bildirimleri için Firebase projesi gereklidir. Şu an mock modunda çalışıyor —
          bildirimler backend loglarında görünür. <code>FCM_SERVER_KEY</code> ortam değişkeni
          ile gerçek bildirimler aktive edilir.
        </p>
      </div>

      {/* Toast */}
      {toast && (
        <div className="toast" style={{
          borderColor: toast.type === 'error' ? 'var(--status-red)' : 'var(--status-green)',
        }}>
          {toast.msg}
        </div>
      )}
    </div>
  );
}
