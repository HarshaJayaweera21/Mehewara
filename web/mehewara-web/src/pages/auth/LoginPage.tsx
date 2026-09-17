import React, { useState, useEffect } from 'react';
import { loginWithCredentials, loginWithGoogle } from '../../services/api';
import type { User } from '../../types/auth';
import './LoginPage.css';

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: { credential: string }) => void;
          }) => void;
          renderButton: (
            element: HTMLElement,
            options: { theme: string; size: string; width?: string; text?: string }
          ) => void;
          prompt: () => void;
        };
      };
    };
  }
}

export const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(() => {
    try {
      const saved = localStorage.getItem('mehewara_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID || '';

  useEffect(() => {
    if (!googleClientId || currentUser) return;

    const setupGoogleButton = () => {
      if (!window.google?.accounts?.id) return false;

      window.google.accounts.id.initialize({
        client_id: googleClientId,
        callback: async (response) => {
          try {
            setLoading(true);
            setError(null);
            const authData = await loginWithGoogle(response.credential);
            localStorage.setItem('mehewara_token', authData.accessToken);
            localStorage.setItem('mehewara_user', JSON.stringify(authData.user));
            setCurrentUser(authData.user);
          } catch (err: unknown) {
            setError(err instanceof Error ? err.message : 'Google authentication failed.');
          } finally {
            setLoading(false);
          }
        },
      });

      const btnContainer = document.getElementById('google-btn-rendered');
      if (btnContainer) {
        btnContainer.innerHTML = '';
        window.google.accounts.id.renderButton(btnContainer, {
          theme: 'outline',
          size: 'large',
          width: '350',
          text: 'signin_with',
        });
        return true;
      }
      return false;
    };

    if (!setupGoogleButton()) {
      const interval = setInterval(() => {
        if (setupGoogleButton()) {
          clearInterval(interval);
        }
      }, 150);
      return () => clearInterval(interval);
    }
  }, [googleClientId, currentUser]);

  const handleCredentialsSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please provide both email and password.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const authData = await loginWithCredentials(email, password);
      localStorage.setItem('mehewara_token', authData.accessToken);
      localStorage.setItem('mehewara_user', JSON.stringify(authData.user));
      setCurrentUser(authData.user);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to sign in.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('mehewara_token');
    localStorage.removeItem('mehewara_user');
    setCurrentUser(null);
    setEmail('');
    setPassword('');
    setError(null);
  };

  const fillCredentials = (userEmail: string, userPass: string) => {
    setEmail(userEmail);
    setPassword(userPass);
    setError(null);
  };

  const handleGoogleFallbackClick = () => {
    if (!googleClientId) {
      setError(
        'Google Client ID is not configured yet. Add VITE_GOOGLE_CLIENT_ID to .env or test with standard credentials below.'
      );
      return;
    }
    window.google?.accounts?.id?.prompt();
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <div className="brand-badge">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
          </div>
          <h1 className="login-title">Mehewara Portal</h1>
          <p className="login-subtitle">Municipal Works Management & Citizen Services</p>
        </div>

        {error && <div className="error-banner">{error}</div>}

        {currentUser ? (
          <div className="profile-card">
            <div className="profile-avatar">
              {currentUser.name.charAt(0).toUpperCase()}
            </div>
            <h3 className="profile-name">{currentUser.name}</h3>
            <p className="profile-email">{currentUser.email}</p>
            <span className="role-badge">{currentUser.role}</span>
            <button className="logout-btn" onClick={handleLogout}>
              Sign Out
            </button>
          </div>
        ) : (
          <>
            <form className="login-form" onSubmit={handleCredentialsSubmit}>
              <div className="form-group">
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  type="email"
                  placeholder="resident@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={loading}
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="password">Password</label>
                <input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={loading}
                  required
                />
              </div>

              <button type="submit" className="submit-btn" disabled={loading}>
                {loading ? 'Signing In...' : 'Sign In'}
              </button>
            </form>

            <div className="divider">
              <span>or continue with</span>
            </div>

            {googleClientId ? (
              <div id="google-btn-rendered" style={{ width: '100%', minHeight: '44px', display: 'flex', justifyContent: 'center' }}></div>
            ) : (
              <button
                type="button"
                className="google-btn"
                onClick={handleGoogleFallbackClick}
                disabled={loading}
              >
                <svg width="18" height="18" viewBox="0 0 18 18">
                  <path
                    fill="#4285F4"
                    d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.616z"
                  />
                  <path
                    fill="#34A853"
                    d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"
                  />
                  <path
                    fill="#FBBC05"
                    d="M3.964 10.707c-.18-.54-.282-1.117-.282-1.707 0-.59.102-1.167.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.039l3.007-2.332z"
                  />
                  <path
                    fill="#EA4335"
                    d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.961L3.964 7.293C4.672 5.166 6.656 3.58 9 3.58z"
                  />
                </svg>
                Sign in with Google
              </button>
            )}

            <div className="demo-credentials">
              <div className="demo-title">Quick Test Accounts</div>
              <div className="demo-chips">
                <button
                  type="button"
                  className="demo-chip"
                  onClick={() => fillCredentials('resident@example.com', 'Resident@123')}
                >
                  Resident
                </button>
                <button
                  type="button"
                  className="demo-chip"
                  onClick={() => fillCredentials('admin@mehewara.gov.lk', 'Admin@123')}
                >
                  Coordinator
                </button>
                <button
                  type="button"
                  className="demo-chip"
                  onClick={() => fillCredentials('crew.drainage@mehewara.gov.lk', 'Crew@123')}
                >
                  Drainage Crew
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
