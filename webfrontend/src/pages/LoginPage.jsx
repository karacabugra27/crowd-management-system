import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { Activity, Mail, Lock, ArrowRight, UserPlus, LogIn } from "lucide-react";

export default function LoginPage() {
  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login, register } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (isRegister) {
        await register(email, password);
      } else {
        await login(email, password);
      }
      navigate("/");
    } catch (err) {
      const msg =
        err.response?.data?.detail || "Bir hata oluştu. Lütfen tekrar deneyin.";
      setError(typeof msg === "string" ? msg : JSON.stringify(msg));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      {/* Animated background */}
      <div className="login-bg">
        <div className="login-bg-orb orb-1" />
        <div className="login-bg-orb orb-2" />
        <div className="login-bg-orb orb-3" />
      </div>

      <div className="login-container">
        {/* Left panel – branding */}
        <div className="login-brand-panel">
          <div className="login-brand-content">
            <div className="login-brand-icon">
              <Activity size={48} />
            </div>
            <h1>CrowdPulse</h1>
            <p>Akıllı Kampüs Kalabalık Yönetim Sistemi</p>
            <div className="login-features">
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Gerçek zamanlı doluluk takibi</span>
              </div>
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Interaktif kampüs haritası</span>
              </div>
              <div className="feature-item">
                <div className="feature-dot" />
                <span>Detaylı analitik raporları</span>
              </div>
            </div>
          </div>
        </div>

        {/* Right panel – form */}
        <div className="login-form-panel">
          <div className="login-form-wrapper">
            <h2>{isRegister ? "Hesap Oluştur" : "Hoş Geldiniz"}</h2>
            <p className="login-subtitle">
              {isRegister
                ? "Yeni bir hesap oluşturun"
                : "Hesabınıza giriş yapın"}
            </p>

            {error && (
              <div className="login-error" id="login-error">
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
                    autoComplete={isRegister ? "new-password" : "current-password"}
                  />
                </div>
              </div>

              <button
                type="submit"
                className="login-submit"
                disabled={loading}
                id="login-submit"
              >
                {loading ? (
                  <span className="spinner" />
                ) : (
                  <>
                    {isRegister ? <UserPlus size={18} /> : <LogIn size={18} />}
                    <span>{isRegister ? "Kayıt Ol" : "Giriş Yap"}</span>
                    <ArrowRight size={18} />
                  </>
                )}
              </button>
            </form>

            <div className="login-toggle">
              <span>
                {isRegister ? "Zaten hesabınız var mı?" : "Hesabınız yok mu?"}
              </span>
              <button
                onClick={() => {
                  setIsRegister(!isRegister);
                  setError("");
                }}
                id="toggle-register"
              >
                {isRegister ? "Giriş Yap" : "Kayıt Ol"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
