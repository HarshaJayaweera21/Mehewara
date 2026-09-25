import React, { useState, useEffect } from 'react';
import {
  loginWithCredentials,
  registerResident,
  loginWithGoogle,
  updateUserProfile,
  uploadProfilePhoto,
  removeProfilePhoto,
} from '../../services/api';
import type { User } from '../../types/auth';
import { LandingPage } from '../landing/LandingPage';
import { AuthShell } from '../landing/AuthShell';
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

const resolveImageUrl = (url?: string | null) => {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `http://localhost:5194${url.startsWith('/') ? '' : '/'}${url}`;
};

interface LoginPageProps {
  onLoginSuccess?: (user: User, accessToken: string) => void;
  onNavigateToReports?: () => void;
}

export const LoginPage: React.FC<LoginPageProps> = ({ onLoginSuccess, onNavigateToReports }) => {
  const [activeTab, setActiveTab] = useState<'signin' | 'signup'>('signin');
  const [publicView, setPublicView] = useState<'landing' | 'auth'>('landing');

  // Sign In state
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // Sign Up state (No profile picture at registration!)
  const [regFirstName, setRegFirstName] = useState('');
  const [regLastName, setRegLastName] = useState('');
  const [regEmail, setRegEmail] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regPhone, setRegPhone] = useState('');

  // Status state
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Authenticated state
  const [currentUser, setCurrentUser] = useState<User | null>(() => {
    try {
      const saved = localStorage.getItem('mehewara_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  // Edit Profile text info state
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [editFirstName, setEditFirstName] = useState('');
  const [editLastName, setEditLastName] = useState('');
  const [editPhone, setEditPhone] = useState('');

  const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID || '';

  useEffect(() => {
    if (!googleClientId || currentUser || activeTab !== 'signin' || publicView !== 'auth') return;

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
            onLoginSuccess?.(authData.user, authData.accessToken);
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
  }, [googleClientId, currentUser, activeTab, publicView, onLoginSuccess]);

  const handleSignInSubmit = async (e: React.FormEvent) => {
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
      onLoginSuccess?.(authData.user, authData.accessToken);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to sign in.');
    } finally {
      setLoading(false);
    }
  };

  const handleSignUpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!regFirstName || !regLastName || !regEmail || !regPassword) {
      setError('Please fill in all required fields.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const authData = await registerResident({
        firstName: regFirstName,
        lastName: regLastName,
        email: regEmail,
        password: regPassword,
        phoneNumber: regPhone || undefined,
      });
      localStorage.setItem('mehewara_token', authData.accessToken);
      localStorage.setItem('mehewara_user', JSON.stringify(authData.user));
      setCurrentUser(authData.user);
      onLoginSuccess?.(authData.user, authData.accessToken);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Registration failed.');
    } finally {
      setLoading(false);
    }
  };

  const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate size client-side (5MB)
    if (file.size > 5 * 1024 * 1024) {
      setError('Image file must be under 5MB.');
      return;
    }

    const token = localStorage.getItem('mehewara_token');
    if (!token) {
      setError('Please sign in first.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMsg(null);
      const updatedUser = await uploadProfilePhoto(token, file);
      localStorage.setItem('mehewara_user', JSON.stringify(updatedUser));
      setCurrentUser(updatedUser);
      setSuccessMsg('Profile photo updated successfully!');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to upload photo.');
    } finally {
      setLoading(false);
      e.target.value = '';
    }
  };

  const handleRemovePhoto = async () => {
    const token = localStorage.getItem('mehewara_token');
    if (!token) return;

    try {
      setLoading(true);
      setError(null);
      setSuccessMsg(null);
      const updatedUser = await removeProfilePhoto(token);
      localStorage.setItem('mehewara_user', JSON.stringify(updatedUser));
      setCurrentUser(updatedUser);
      setSuccessMsg('Profile photo removed.');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to remove photo.');
    } finally {
      setLoading(false);
    }
  };

  const startEditProfile = () => {
    if (!currentUser) return;
    setEditFirstName(currentUser.firstName || currentUser.name.split(' ')[0] || '');
    setEditLastName(currentUser.lastName || currentUser.name.split(' ').slice(1).join(' ') || '');
    setEditPhone(currentUser.phoneNumber || '');
    setIsEditingProfile(true);
    setError(null);
    setSuccessMsg(null);
  };

  const handleProfileUpdateSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const token = localStorage.getItem('mehewara_token');
    if (!token) {
      setError('Session expired. Please sign in again.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccessMsg(null);
      const updatedUser = await updateUserProfile(token, {
        firstName: editFirstName,
        lastName: editLastName,
        phoneNumber: editPhone,
      });
      localStorage.setItem('mehewara_user', JSON.stringify(updatedUser));
      setCurrentUser(updatedUser);
      setIsEditingProfile(false);
      setSuccessMsg('Profile updated successfully!');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to update profile.');
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
    setPublicView('landing');
    setIsEditingProfile(false);
    setError(null);
    setSuccessMsg(null);
  };

  const handleGoogleFallbackClick = () => {
    if (!googleClientId) {
      setError('Google Client ID is not configured yet. Add VITE_GOOGLE_CLIENT_ID to .env.');
      return;
    }
    window.google?.accounts?.id?.prompt();
  };

  const fullImageUrl = resolveImageUrl(currentUser?.profileImageUrl);

  if (!currentUser) {
    if (publicView === 'landing') {
      return (
        <LandingPage
          onSignIn={() => {
            setActiveTab('signin');
            setError(null);
            setPublicView('auth');
          }}
          onSignUp={() => {
            setActiveTab('signup');
            setError(null);
            setPublicView('auth');
          }}
        />
      );
    }

    const authPanel = (
      <>
        {error && <div className="error-banner" role="alert">{error}</div>}
        {successMsg && <div className="success-banner" role="status">{successMsg}</div>}

        <div className="auth-tabs" aria-label="Account access">
          <button
            type="button"
            className={`auth-tab ${activeTab === 'signin' ? 'active' : ''}`}
            aria-pressed={activeTab === 'signin'}
            onClick={() => {
              setActiveTab('signin');
              setError(null);
            }}
          >
            Sign in
          </button>
          <button
            type="button"
            className={`auth-tab ${activeTab === 'signup' ? 'active' : ''}`}
            aria-pressed={activeTab === 'signup'}
            onClick={() => {
              setActiveTab('signup');
              setError(null);
            }}
          >
            Create account
          </button>
        </div>

        {activeTab === 'signin' ? (
          <>
            <form className="login-form" onSubmit={handleSignInSubmit}>
              <div className="form-group">
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  type="email"
                  autoComplete="email"
                  placeholder="resident@example.com"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  disabled={loading}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="password">Password</label>
                <input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  disabled={loading}
                  required
                />
              </div>
              <button type="submit" className="submit-btn" disabled={loading}>
                {loading ? 'Signing in…' : 'Sign in to Mehewara'}
              </button>
            </form>

            <div className="divider"><span>or continue with</span></div>
            {googleClientId ? (
              <div id="google-btn-rendered" className="google-render-target" />
            ) : (
              <button type="button" className="google-btn" onClick={handleGoogleFallbackClick} disabled={loading}>
                <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
                  <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.616z" />
                  <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z" />
                  <path fill="#FBBC05" d="M3.964 10.707c-.18-.54-.282-1.117-.282-1.707 0-.59.102-1.167.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.039l3.007-2.332z" />
                  <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.961L3.964 7.293C4.672 5.166 6.656 3.58 9 3.58z" />
                </svg>
                Sign in with Google
              </button>
            )}
          </>
        ) : (
          <form className="login-form" onSubmit={handleSignUpSubmit}>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="regFirstName">First name</label>
                <input id="regFirstName" type="text" autoComplete="given-name" placeholder="Kasun" value={regFirstName} onChange={(event) => setRegFirstName(event.target.value)} disabled={loading} required />
              </div>
              <div className="form-group">
                <label htmlFor="regLastName">Last name</label>
                <input id="regLastName" type="text" autoComplete="family-name" placeholder="Perera" value={regLastName} onChange={(event) => setRegLastName(event.target.value)} disabled={loading} required />
              </div>
            </div>
            <div className="form-group">
              <label htmlFor="regEmail">Email address</label>
              <input id="regEmail" type="email" autoComplete="email" placeholder="kasun@example.com" value={regEmail} onChange={(event) => setRegEmail(event.target.value)} disabled={loading} required />
            </div>
            <div className="form-group">
              <label htmlFor="regPhone">Phone number <span className="optional-label">Optional</span></label>
              <input id="regPhone" type="tel" autoComplete="tel" placeholder="+94 77 123 4567" value={regPhone} onChange={(event) => setRegPhone(event.target.value)} disabled={loading} />
            </div>
            <div className="form-group">
              <label htmlFor="regPassword">Password</label>
              <input id="regPassword" type="password" autoComplete="new-password" placeholder="At least 6 characters" value={regPassword} onChange={(event) => setRegPassword(event.target.value)} disabled={loading} required minLength={6} />
            </div>
            <button type="submit" className="submit-btn" disabled={loading}>
              {loading ? 'Creating account…' : 'Create resident account'}
            </button>
          </form>
        )}
      </>
    );

    return (
      <AuthShell
        mode={activeTab}
        onBack={() => {
          setError(null);
          setPublicView('landing');
        }}
        onSwitch={() => {
          setError(null);
          setActiveTab((tab) => tab === 'signin' ? 'signup' : 'signin');
        }}
      >
        {authPanel}
      </AuthShell>
    );
  }

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <div className="brand-badge">
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
          </div>
          <h1 className="login-title">Mehewara Portal</h1>
          <p className="login-subtitle">Municipal Works Management & Citizen Services</p>
        </div>

        {error && <div className="error-banner">{error}</div>}
        {successMsg && <div className="success-banner">{successMsg}</div>}

        {currentUser ? (
          <div className="profile-card">
            <div className="profile-avatar-section">
              <div className="profile-avatar-wrapper">
                {fullImageUrl ? (
                  <img
                    src={fullImageUrl}
                    alt={currentUser.name}
                    className="profile-avatar-img"
                    onError={(e) => {
                      (e.target as HTMLElement).style.display = 'none';
                    }}
                  />
                ) : (
                  <div className="profile-avatar-fallback">
                    {currentUser.name ? currentUser.name.charAt(0).toUpperCase() : 'U'}
                  </div>
                )}
              </div>

              <div className="avatar-actions">
                <label className="photo-upload-label" title="Upload Photo">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
                    <circle cx="12" cy="13" r="4"/>
                  </svg>
                  {currentUser.profileImageUrl ? 'Change Photo' : 'Upload Photo'}
                  <input
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    onChange={handlePhotoUpload}
                    disabled={loading}
                  />
                </label>

                {currentUser.profileImageUrl && (
                  <button
                    type="button"
                    className="photo-remove-btn"
                    onClick={handleRemovePhoto}
                    disabled={loading}
                    title="Remove Photo"
                  >
                    Remove
                  </button>
                )}
              </div>
            </div>

            <h3 className="profile-name">{currentUser.name}</h3>
            <p className="profile-email">{currentUser.email}</p>
            {currentUser.phoneNumber && (
              <p className="profile-detail">📞 {currentUser.phoneNumber}</p>
            )}
            <span className="role-badge">{currentUser.role}</span>

            {!isEditingProfile ? (
              <div className="profile-actions" style={{ flexDirection: 'column', gap: '0.75rem' }}>
                <button
                  type="button"
                  className="submit-btn"
                  onClick={() => onNavigateToReports?.()}
                >
                  📋 Go to Reports Portal
                </button>
                <div style={{ display: 'flex', gap: '0.5rem', width: '100%' }}>
                  <button
                    type="button"
                    className="secondary-btn"
                    style={{ flex: 1 }}
                    onClick={startEditProfile}
                    disabled={loading}
                  >
                    Edit Info
                  </button>
                  <button
                    type="button"
                    className="logout-btn"
                    style={{ flex: 1 }}
                    onClick={handleLogout}
                    disabled={loading}
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            ) : (
              <form className="edit-profile-box" onSubmit={handleProfileUpdateSubmit}>
                <div className="edit-profile-title">Update Profile Details</div>

                <div className="form-row">
                  <div className="form-group">
                    <label htmlFor="editFirstName">First Name</label>
                    <input
                      id="editFirstName"
                      type="text"
                      value={editFirstName}
                      onChange={(e) => setEditFirstName(e.target.value)}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label htmlFor="editLastName">Last Name</label>
                    <input
                      id="editLastName"
                      type="text"
                      value={editLastName}
                      onChange={(e) => setEditLastName(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="form-group" style={{ marginTop: '0.75rem' }}>
                  <label htmlFor="editPhone">Phone Number</label>
                  <input
                    id="editPhone"
                    type="tel"
                    placeholder="+94771234567"
                    value={editPhone}
                    onChange={(e) => setEditPhone(e.target.value)}
                  />
                </div>

                <div className="profile-actions" style={{ marginTop: '1.25rem' }}>
                  <button type="submit" className="submit-btn" disabled={loading}>
                    {loading ? 'Saving...' : 'Save Changes'}
                  </button>
                  <button
                    type="button"
                    className="secondary-btn"
                    onClick={() => setIsEditingProfile(false)}
                    disabled={loading}
                  >
                    Cancel
                  </button>
                </div>
              </form>
            )}
          </div>
        ) : (
          <>
            <div className="auth-tabs">
              <button
                type="button"
                className={`auth-tab ${activeTab === 'signin' ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab('signin');
                  setError(null);
                }}
              >
                Sign In
              </button>
              <button
                type="button"
                className={`auth-tab ${activeTab === 'signup' ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab('signup');
                  setError(null);
                }}
              >
                Create Account
              </button>
            </div>

            {activeTab === 'signin' ? (
              <>
                <form className="login-form" onSubmit={handleSignInSubmit}>
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

                  <div className="dev-login-tip">
                    <div style={{ fontWeight: 600, color: '#94a3b8', marginBottom: '0.4rem', fontSize: '0.775rem' }}>
                      ⚡ Quick Test Fill:
                    </div>
                    <div className="dev-login-buttons">
                      <button
                        type="button"
                        className="quick-login-chip"
                        onClick={() => {
                          setEmail('resident@example.com');
                          setPassword('Resident@123');
                        }}
                      >
                        👤 Resident (Kamal)
                      </button>
                      <button
                        type="button"
                        className="quick-login-chip"
                        onClick={() => {
                          setEmail('admin@mehewara.gov.lk');
                          setPassword('Admin@123');
                        }}
                      >
                        🛡️ Coordinator (Admin)
                      </button>
                    </div>
                  </div>
                </form>

                <div className="divider">
                  <span>or continue with</span>
                </div>

                {googleClientId ? (
                  <div
                    id="google-btn-rendered"
                    style={{
                      width: '100%',
                      minHeight: '44px',
                      display: 'flex',
                      justifyContent: 'center',
                    }}
                  ></div>
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
              </>
            ) : (
              <form className="login-form" onSubmit={handleSignUpSubmit}>
                <div className="form-row">
                  <div className="form-group">
                    <label htmlFor="regFirstName">First Name *</label>
                    <input
                      id="regFirstName"
                      type="text"
                      placeholder="Kasun"
                      value={regFirstName}
                      onChange={(e) => setRegFirstName(e.target.value)}
                      disabled={loading}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label htmlFor="regLastName">Last Name *</label>
                    <input
                      id="regLastName"
                      type="text"
                      placeholder="Perera"
                      value={regLastName}
                      onChange={(e) => setRegLastName(e.target.value)}
                      disabled={loading}
                      required
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label htmlFor="regEmail">Email address *</label>
                  <input
                    id="regEmail"
                    type="email"
                    placeholder="kasun.perera@example.com"
                    value={regEmail}
                    onChange={(e) => setRegEmail(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="regPhone">Phone Number (optional)</label>
                  <input
                    id="regPhone"
                    type="tel"
                    placeholder="+94771234567"
                    value={regPhone}
                    onChange={(e) => setRegPhone(e.target.value)}
                    disabled={loading}
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="regPassword">Password * (min 6 characters)</label>
                  <input
                    id="regPassword"
                    type="password"
                    placeholder="••••••••"
                    value={regPassword}
                    onChange={(e) => setRegPassword(e.target.value)}
                    disabled={loading}
                    required
                    minLength={6}
                  />
                </div>

                <button type="submit" className="submit-btn" disabled={loading}>
                  {loading ? 'Creating Account...' : 'Create Resident Account'}
                </button>
              </form>
            )}
          </>
        )}
      </div>
    </div>
  );
};
