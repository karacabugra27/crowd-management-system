import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import {
  Shield,
  Mail,
  Lock,
  ArrowRight,
  LogIn,
  ArrowLeft,
} from "lucide-react";
import { translateError } from "../utils/errors";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(email, password);
      navigate("/admin");
    } catch (err) {
      setError(translateError(err, "Giriş yapılamadı. E-posta veya şifre hatalı."));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-bg">
        <div className="login-bg-orb orb-1" />
        <div className="login-bg-orb orb-2" />
        <div className="login-bg-orb orb-3" />
      </div>

      <div className="login-container">
        <div className="login-brand-panel">
          <div className="login-brand-content">
            <div className="login-brand-icon">
              <Shield size={48} />
            </div>
            <h1>Crowdly</h1>
            <p>Yönetim Paneli</p>
            <div className="login-features">
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Alan ve kapasite yönetimi</span>
              </div>
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Tarayıcı ve API anahtarı kontrolü</span>
              </div>
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Bluetooth yoğunluk kayıtları</span>
              </div>
            </div>
          </div>
        </div>

        <div className="login-form-panel">
          <div className="login-form-wrapper">
            <Link to="/" className="login-back-link">
              <ArrowLeft size={16} />
              <span>Kullanıcı sayfasına dön</span>
            </Link>

            <h2>Yönetici Girişi</h2>
            <p className="login-subtitle">
              Yönetim paneline erişmek için giriş yapın
            </p>

            {error && (
              <div className="login-error" role="alert">
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit} className="login-form">
              <div className="form-group">
                <label htmlFor="email">E-posta</label>
                <div className="input-wrapper">
                  <Mail size={18} className="input-icon" />
                  <input
                    id="email"
                    type="email"
                    placeholder="ornek@mail.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    autoComplete="email"
                  />
                </div>
              </div>

              <div className="form-group">
                <label htmlFor="password">Şifre</label>
                <div className="input-wrapper">
                  <Lock size={18} className="input-icon" />
                  <input
                    id="password"
                    type="password"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    minLength={8}
                    autoComplete="current-password"
                  />
                </div>
              </div>

              <button
                type="submit"
                className="login-submit"
                disabled={loading}
              >
                {loading ? (
                  <span className="spinner" />
                ) : (
                  <>
                    <LogIn size={18} />
                    <span>Giriş Yap</span>
                    <ArrowRight size={18} />
                  </>
                )}
              </button>
            </form>

            <p className="login-note">
              Hesap oluşturmak için sistem yöneticinizle iletişime geçin.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
