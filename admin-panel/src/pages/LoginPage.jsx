import { useState } from 'react';
import { apiRequest, setToken } from '../api/client';

export default function LoginPage({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const data = await apiRequest('/api/auth/login', {
        auth: false,
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      const token = data.access_token || data.token;

      if (!token) {
        throw new Error('Backend yanıtında access_token bulunamadı.');
      }

      setToken(token);
      onLogin();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-shell">
      <section className="login-hero">
        <div className="brand-pill">Campus Crowd Management</div>

        <h1>Akıllı Kampüs Admin Paneli</h1>

        <p>
          Bluetooth dinleyicilerden gelen yoğunluk verilerini, alanları ve sistem
          durumunu tek merkezden izle.
        </p>

        <div className="hero-grid">
          <div>
            <strong>Canlı</strong>
            <span>Backend bağlantısı</span>
          </div>
          <div>
            <strong>JWT</strong>
            <span>Güvenli oturum</span>
          </div>
          <div>
            <strong>Admin</strong>
            <span>Yönetim ekranı</span>
          </div>
        </div>
      </section>

      <section className="login-card">
        <div className="login-card-header">
          <div className="logo-mark">R</div>
          <div>
            <h2>Admin Girişi</h2>
            <p>Sisteme devam etmek için giriş yap.</p>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          <label htmlFor="email">Email</label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="admin@example.com"
            required
            autoComplete="username"
          />

          <label htmlFor="password">Şifre</label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            required
            autoComplete="current-password"
          />

          {error && <div className="error-box">{error}</div>}

          <button className="primary-btn" type="submit" disabled={loading}>
            {loading ? 'Giriş yapılıyor...' : 'Giriş Yap'}
          </button>
        </form>
      </section>
    </main>
  );
}
