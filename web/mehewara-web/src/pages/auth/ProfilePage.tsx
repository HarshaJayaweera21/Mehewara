import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { LoginPage } from './LoginPage';
import { getHomePathForRole } from '../../types/access';
import { ROUTES } from '../../routes/paths';
import type { User } from '../../types/auth';
import { Header, HeroBanner } from '../../components/common';
import { OpsNavDrawer } from '../../components/common/OpsNavDrawer';
import {
  getCurrentUser,
  updateUserProfile,
  uploadProfilePhoto,
  removeProfilePhoto,
} from '../../services/api';
import './ProfilePage.css';

export interface ProfilePageProps {
  currentUser?: User | null;
  token?: string | null;
  onLogout?: () => void;
  onNavigateBack?: () => void;
}

export const ProfilePage: React.FC<ProfilePageProps> = ({
  currentUser: propsUser,
  token: propsToken,
  onLogout,
}) => {
  const { currentUser: authUser, token: authToken, logout, login, updateCurrentUser } = useAuth();
  const navigate = useNavigate();

  const [freshUser, setFreshUser] = useState<User | null>(null);
  const [isNavDrawerOpen, setIsNavDrawerOpen] = useState(false);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  // Resident edit profile states
  const [isEditing, setIsEditing] = useState(false);
  const [editFirstName, setEditFirstName] = useState('');
  const [editLastName, setEditLastName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveSuccess, setSaveSuccess] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const effectiveUser = freshUser ?? propsUser ?? authUser;
  const effectiveToken = propsToken ?? authToken;

  const returnPath = effectiveUser ? getHomePathForRole(effectiveUser.role) : ROUTES.HOME;

  // Initialize edit fields whenever effectiveUser changes or when edit mode toggles
  useEffect(() => {
    if (effectiveUser && !isEditing) {
      const parts = (effectiveUser.name || '').trim().split(/\s+/);
      setEditFirstName(effectiveUser.firstName || parts[0] || '');
      setEditLastName(
        effectiveUser.lastName || (parts.length > 1 ? parts.slice(1).join(' ') : '')
      );
      setEditPhone(effectiveUser.phoneNumber || '');
    }
  }, [effectiveUser, isEditing]);

  // Attempt to refresh profile details from backend /api/auth/me
  useEffect(() => {
    let active = true;
    if (effectiveToken && (effectiveUser?.role === 'ADMIN' || effectiveUser?.role === 'RESIDENT')) {
      getCurrentUser(effectiveToken)
        .then((fresh) => {
          if (active && fresh) {
            setFreshUser(fresh);
          }
        })
        .catch(() => {
          // Keep cached user from AuthContext on error/offline
        });
    }
    return () => {
      active = false;
    };
  }, [effectiveToken, effectiveUser?.role]);

  if (!effectiveUser) return null;

  const handleLogout = () => {
    if (onLogout) {
      onLogout();
    } else {
      logout();
      navigate(ROUTES.LOGIN);
    }
  };


  const handleCopy = (text: string, key: string) => {
    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(text);
    }
    setCopiedKey(key);
    setTimeout(() => {
      setCopiedKey((prev) => (prev === key ? null : prev));
    }, 2200);
  };

  // --------------------------------------------------------------------------
  // RESIDENT EDIT PROFILE HANDLERS
  // --------------------------------------------------------------------------
  const handleStartEdit = () => {
    const parts = (effectiveUser.name || '').trim().split(/\s+/);
    setEditFirstName(effectiveUser.firstName || parts[0] || '');
    setEditLastName(
      effectiveUser.lastName || (parts.length > 1 ? parts.slice(1).join(' ') : '')
    );
    setEditPhone(effectiveUser.phoneNumber || '');
    setSaveError(null);
    setSaveSuccess(null);
    setIsEditing(true);
  };

  const handleCancelEdit = () => {
    setSaveError(null);
    setIsEditing(false);
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editFirstName.trim() || !editLastName.trim()) {
      setSaveError('First name and last name are required.');
      return;
    }

    if (!effectiveToken) {
      setSaveError('Authentication token missing. Please sign in again.');
      return;
    }

    try {
      setIsSaving(true);
      setSaveError(null);

      const updated = await updateUserProfile(effectiveToken, {
        firstName: editFirstName.trim(),
        lastName: editLastName.trim(),
        phoneNumber: editPhone.trim() || undefined,
      });

      setFreshUser(updated);
      updateCurrentUser(updated);
      setSaveSuccess('Your citizen profile details have been successfully updated.');
      setIsEditing(false);
    } catch (err: unknown) {
      setSaveError(err instanceof Error ? err.message : 'Failed to update profile details.');
    } finally {
      setIsSaving(false);
    }
  };

  const handlePhotoFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Reset input value so same file can be re-selected if desired
    e.target.value = '';

    if (file.size > 5 * 1024 * 1024) {
      setSaveError('Profile photo size must be less than 5MB.');
      return;
    }

    if (!effectiveToken) {
      setSaveError('Authentication token missing.');
      return;
    }

    try {
      setIsUploadingPhoto(true);
      setSaveError(null);

      const updated = await uploadProfilePhoto(effectiveToken, file);
      setFreshUser(updated);
      updateCurrentUser(updated);
      setSaveSuccess('Profile photo uploaded and updated successfully.');
    } catch (err: unknown) {
      setSaveError(err instanceof Error ? err.message : 'Failed to upload profile photo.');
    } finally {
      setIsUploadingPhoto(false);
    }
  };

  const handleRemovePhotoClick = async () => {
    if (!effectiveToken) return;

    try {
      setIsUploadingPhoto(true);
      setSaveError(null);

      const updated = await removeProfilePhoto(effectiveToken);
      setFreshUser(updated);
      updateCurrentUser(updated);
      setSaveSuccess('Profile photo removed.');
    } catch (err: unknown) {
      setSaveError(err instanceof Error ? err.message : 'Failed to remove profile photo.');
    } finally {
      setIsUploadingPhoto(false);
    }
  };

  // --------------------------------------------------------------------------
  // CREW LEADER FALLBACK (Preserves existing crew role behaviors & test mocks)
  // --------------------------------------------------------------------------
  if (effectiveUser.role !== 'ADMIN' && effectiveUser.role !== 'RESIDENT') {
    const destinationLabel =
      returnPath === ROUTES.MY_JOBS ? 'My Jobs' : 'Reports Portal';

    return (
      <div style={{ minHeight: '100vh', background: '#0f172a' }}>
        <header
          style={{
            background: 'rgba(30, 41, 59, 0.9)',
            padding: '0.85rem 2rem',
            borderBottom: '1px solid #334155',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <button
            type="button"
            onClick={() => navigate(returnPath)}
            style={{
              background: '#0f172a',
              color: '#38bdf8',
              border: '1px solid #334155',
              borderRadius: '8px',
              padding: '0.45rem 1rem',
              cursor: 'pointer',
              fontWeight: 600,
              fontSize: '0.875rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
            }}
          >
            ← Back to {destinationLabel}
          </button>
          <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
            Logged in as: <strong style={{ color: '#f8fafc' }}>{effectiveUser.name}</strong> ({effectiveUser.role})
          </span>
        </header>

        <LoginPage
          onNavigateToReports={() => navigate(returnPath)}
          onNavigateToLanding={() => navigate(ROUTES.HOME)}
          onLoginSuccess={(user, token) => {
            login(user, token);
            navigate(returnPath);
          }}
        />
      </div>
    );
  }

  // Helper to compute initials for avatar fallback
  const getInitials = (fullName: string) => {
    const parts = fullName.trim().split(/\s+/);
    return parts.length >= 2
      ? `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
      : fullName.slice(0, 2).toUpperCase();
  };

  // --------------------------------------------------------------------------
  // RESIDENT PROFILE VIEW (Self-Service Editable)
  // --------------------------------------------------------------------------
  if (effectiveUser.role === 'RESIDENT') {
    const residentName =
      effectiveUser.firstName && effectiveUser.lastName
        ? `${effectiveUser.firstName} ${effectiveUser.lastName}`
        : effectiveUser.name || 'Resident Citizen';
    const residentEmail = effectiveUser.email;
    const residentPhone = effectiveUser.phoneNumber;
    const residentId = effectiveUser.id;
    const initials = getInitials(residentName);

    return (
      <div className="profile-page-container">
        <div className="profile-content-wrap">
          {/* Hidden File Input for Avatar Upload */}
          <input
            type="file"
            ref={fileInputRef}
            onChange={handlePhotoFileChange}
            accept="image/png,image/jpeg,image/webp,image/jpg"
            style={{ display: 'none' }}
          />

          {/* 1. Header (Resident Mode) */}
          <Header
            currentUser={effectiveUser}
            onLogout={handleLogout}
            onOpenProfile={() => {}}
            onBrandClick={() => navigate(ROUTES.HOME)}
            roleBadgeText="Resident"
            showName={true}
            showMenuButton={false}
          />

          {/* 2. Hero Welcome Banner with Top-Right Verified Badge & Status Pill */}
          <HeroBanner
            badge="RESIDENT PROFILE"
            title="Citizen Profile & Municipal Account"
            subtitle="Manage your personal contact details, review municipal ward registration, and track citizen services."
            ariaLabel="Resident Profile Banner"
            actions={
              <div className="profile-status-group">
                <span className="profile-verified-badge">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                    <polyline points="9 12 11 14 15 10" />
                  </svg>
                  <span>Verified Citizen</span>
                </span>

                <span className="profile-status-pill">
                  <span className="profile-status-dot" />
                  <span>Active Account</span>
                </span>
              </div>
            }
          />

          {/* Success / Error Banners */}
          {saveSuccess && (
            <div className="profile-alert-banner success">
              <span>{saveSuccess}</span>
              <button
                type="button"
                className="profile-alert-close-btn"
                onClick={() => setSaveSuccess(null)}
                aria-label="Dismiss alert"
              >
                &times;
              </button>
            </div>
          )}

          {saveError && (
            <div className="profile-alert-banner error">
              <span>{saveError}</span>
              <button
                type="button"
                className="profile-alert-close-btn"
                onClick={() => setSaveError(null)}
                aria-label="Dismiss alert"
              >
                &times;
              </button>
            </div>
          )}

          {/* 4. Main Profile Grid Layout */}
          <div className="profile-grid-layout">
            {/* Card A: Citizen Identity & Self-Service Contact Details */}
            <div className="profile-card profile-card-half">
              <div className="profile-card-header">
                <div className="profile-card-title-group">
                  <div className="profile-card-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                      <circle cx="12" cy="7" r="4" />
                    </svg>
                  </div>
                  <div>
                    <h3 className="profile-card-title">Citizen Identification</h3>
                    <p className="profile-card-subtitle">Personal contact information & account details</p>
                  </div>
                </div>

                {!isEditing ? (
                  <button
                    type="button"
                    className="profile-edit-toggle-btn"
                    onClick={handleStartEdit}
                    title="Edit personal contact details"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                    </svg>
                    <span>Edit Profile</span>
                  </button>
                ) : (
                  <button
                    type="button"
                    className="profile-cancel-btn"
                    onClick={handleCancelEdit}
                    style={{ padding: '0.35rem 0.75rem', fontSize: '0.8rem' }}
                  >
                    Cancel
                  </button>
                )}
              </div>

              {/* Citizen Hero Block with Avatar & Photo Actions */}
              <div className="officer-hero-block">
                <div className="officer-avatar-wrap">
                  {effectiveUser.profileImageUrl ? (
                    <img
                      src={effectiveUser.profileImageUrl}
                      alt={residentName}
                      className="officer-avatar-img"
                    />
                  ) : (
                    <div className="officer-avatar-initials">{initials}</div>
                  )}
                  <div className="officer-verified-seal" title="Verified Municipal Citizen">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                      <polyline points="20 6 9 17 4 12" />
                    </svg>
                  </div>
                </div>

                <div className="officer-meta-block">
                  <h3 className="officer-name">{residentName}</h3>
                  <div className="officer-designation">Verified Municipal Resident</div>
                  <div className="officer-department">Colombo Municipal Council Community Member</div>

                  {/* Profile Photo Quick Controls */}
                  <div className="profile-photo-buttons">
                    <button
                      type="button"
                      className="profile-photo-btn"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={isUploadingPhoto}
                      title="Upload new profile picture"
                    >
                      {isUploadingPhoto ? 'Uploading...' : '📷 Change Photo'}
                    </button>
                    {effectiveUser.profileImageUrl && (
                      <button
                        type="button"
                        className="profile-photo-btn remove"
                        onClick={handleRemovePhotoClick}
                        disabled={isUploadingPhoto}
                        title="Remove profile picture"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* View Mode vs Edit Mode */}
              {!isEditing ? (
                <div className="profile-details-table">
                  <div className="profile-detail-row">
                    <span className="profile-detail-label">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                        <line x1="16" y1="2" x2="16" y2="6" />
                        <line x1="8" y1="2" x2="8" y2="6" />
                        <line x1="3" y1="10" x2="21" y2="10" />
                      </svg>
                      Citizen Account ID
                    </span>
                    <span className="profile-detail-value">
                      <code className="profile-detail-code">{residentId}</code>
                      <button
                        type="button"
                        className={`profile-copy-btn ${copiedKey === 'res-id' ? 'copied' : ''}`}
                        onClick={() => handleCopy(residentId, 'res-id')}
                        title="Copy Citizen ID"
                      >
                        {copiedKey === 'res-id' ? (
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                            <polyline points="20 6 9 17 4 12" />
                          </svg>
                        ) : (
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                          </svg>
                        )}
                      </button>
                    </span>
                  </div>

                  <div className="profile-detail-row">
                    <span className="profile-detail-label">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                        <polyline points="22,6 12,13 2,6" />
                      </svg>
                      Registered Email
                    </span>
                    <span className="profile-detail-value">
                      <span>{residentEmail}</span>
                    </span>
                  </div>

                  <div className="profile-detail-row">
                    <span className="profile-detail-label">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                      </svg>
                      Contact Phone Number
                    </span>
                    <span className="profile-detail-value">
                      {residentPhone ? (
                        <span>{residentPhone}</span>
                      ) : (
                        <span style={{ color: 'var(--mw-muted)', fontStyle: 'italic', fontWeight: 400 }}>
                          Not provided (click Edit to add)
                        </span>
                      )}
                    </span>
                  </div>

                  <div className="profile-detail-row">
                    <span className="profile-detail-label">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                      </svg>
                      Account Role
                    </span>
                    <span className="profile-detail-value">
                      <span style={{ color: 'var(--mw-forest)', fontWeight: 700 }}>RESIDENT (Citizen Contributor)</span>
                    </span>
                  </div>

                  <div className="profile-detail-row">
                    <span className="profile-detail-label">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                      </svg>
                      Verification Status
                    </span>
                    <span className="profile-detail-value">
                      <span style={{ color: '#166534', fontWeight: 600 }}>Active Verified Citizen</span>
                    </span>
                  </div>
                </div>
              ) : (
                /* Editable Form Mode */
                <form onSubmit={handleSaveProfile} className="profile-edit-form">
                  <div className="profile-form-row">
                    <div className="profile-form-group">
                      <label htmlFor="edit-first-name" className="profile-form-label">
                        First Name *
                      </label>
                      <input
                        id="edit-first-name"
                        type="text"
                        className="profile-form-input"
                        value={editFirstName}
                        onChange={(e) => setEditFirstName(e.target.value)}
                        placeholder="First Name"
                        required
                      />
                    </div>

                    <div className="profile-form-group">
                      <label htmlFor="edit-last-name" className="profile-form-label">
                        Last Name *
                      </label>
                      <input
                        id="edit-last-name"
                        type="text"
                        className="profile-form-input"
                        value={editLastName}
                        onChange={(e) => setEditLastName(e.target.value)}
                        placeholder="Last Name"
                        required
                      />
                    </div>
                  </div>

                  <div className="profile-form-group">
                    <label htmlFor="edit-phone" className="profile-form-label">
                      Contact Phone Number
                    </label>
                    <input
                      id="edit-phone"
                      type="tel"
                      className="profile-form-input"
                      value={editPhone}
                      onChange={(e) => setEditPhone(e.target.value)}
                      placeholder="+94 77 123 4567"
                    />
                    <span className="profile-form-hint">
                      Used by municipal dispatchers to coordinate on-site defect inspections.
                    </span>
                  </div>

                  <div className="profile-form-group">
                    <label className="profile-form-label">Registered Email</label>
                    <input
                      type="email"
                      className="profile-form-input"
                      value={residentEmail}
                      disabled
                      title="Email is your primary login credential"
                    />
                    <span className="profile-form-hint">
                      Email address is linked to your council login credentials.
                    </span>
                  </div>

                  <div className="profile-form-actions">
                    <button
                      type="button"
                      className="profile-cancel-btn"
                      onClick={handleCancelEdit}
                      disabled={isSaving}
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      className="profile-save-btn"
                      disabled={isSaving}
                    >
                      {isSaving ? 'Saving Changes...' : 'Save Profile Changes'}
                    </button>
                  </div>
                </form>
              )}
            </div>

            {/* Card B: Municipal Council Resident Services */}
            <div className="profile-card profile-card-half">
              <div className="profile-card-header">
                <div className="profile-card-title-group">
                  <div className="profile-card-icon">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M3 21h18M3 7v14M21 7v14M6 11h2M6 15h2M16 11h2M16 15h2M10 21v-4a2 2 0 0 1 4 0v4M4 7l8-4 8 4" />
                    </svg>
                  </div>
                  <div>
                    <h3 className="profile-card-title">Municipal Council Authority</h3>
                    <p className="profile-card-subtitle">Civic governance & resident services directory</p>
                  </div>
                </div>
              </div>

              <div className="profile-details-table">
                <div className="profile-detail-row">
                  <span className="profile-detail-label">Local Governing Body</span>
                  <span className="profile-detail-value">
                    <span>Colombo Municipal Council (CMC)</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">Official Council Name</span>
                  <span className="profile-detail-value">
                    <span style={{ fontSize: '0.8125rem' }}>කොළඹ මහ නගර සභාව / கொழும்பு மாநகர சபை</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">Civic Headquarters</span>
                  <span className="profile-detail-value">
                    <span>Town Hall, F. R. Senanayake Mawatha, Colombo 07</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">Administrative Wards</span>
                  <span className="profile-detail-value">
                    <span>47 Wards across 5 Electoral Districts</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">National Citizen Helpline</span>
                  <span className="profile-detail-value">
                    <span style={{ color: '#166534', fontWeight: 700 }}>1919 (Toll-Free 24/7)</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">Council Operations Hotline</span>
                  <span className="profile-detail-value">
                    <span>+94 11 268 4290 / +94 11 269 3151</span>
                  </span>
                </div>

                <div className="profile-detail-row">
                  <span className="profile-detail-label">Official Web Portal</span>
                  <span className="profile-detail-value">
                    <a
                      href="https://colombo.mc.gov.lk"
                      target="_blank"
                      rel="noreferrer"
                      style={{ color: 'var(--mw-forest)', textDecoration: 'underline' }}
                    >
                      colombo.mc.gov.lk
                    </a>
                  </span>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    );
  }

  // --------------------------------------------------------------------------
  // REDESIGNED MUNICIPAL COORDINATOR PROFILE VIEW (ADMIN ONLY)
  // --------------------------------------------------------------------------
  const officerName = effectiveUser.name || 'Municipal Coordinator';
  const officerEmail = effectiveUser.email || 'admin@mehewara.gov.lk';
  const officerPhone = effectiveUser.phoneNumber || '+94 11 234 5670';
  const officerId = effectiveUser.id || 'a0000000-0000-0000-0000-000000000001';
  const initials = getInitials(officerName);

  return (
    <div className="profile-page-container">
      <div className="profile-content-wrap">
        {/* 1. Unified Coordinator Header */}
        <Header
          currentUser={effectiveUser}
          onLogout={handleLogout}
          onOpenProfile={() => {}}
          onBrandClick={() => navigate(ROUTES.OPERATIONS)}
          roleBadgeText="Municipal Coordinator"
          showName={true}
          showMenuButton={true}
          onMenuClick={() => setIsNavDrawerOpen((prev) => !prev)}
          isMenuOpen={isNavDrawerOpen}
        />

        {/* 2. Operations Drawer */}
        <OpsNavDrawer
          isOpen={isNavDrawerOpen}
          onClose={() => setIsNavDrawerOpen(false)}
          activePage="profile"
          onNavigateToDashboard={() => navigate(ROUTES.OPERATIONS)}
          onNavigateToProblems={() => navigate(ROUTES.PROBLEMS)}
          onNavigateToUncertainReports={() => navigate(ROUTES.UNCERTAIN_REPORTS)}
          onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
          onNavigateToCrews={() => navigate(ROUTES.CREWS)}
          onNavigateToWorkOrders={() => navigate(ROUTES.WORK_ORDERS)}
        />

        {/* 3. Hero Welcome Banner with Top-Right Verified Badge & Status Pill */}
        <HeroBanner
          badge="OFFICIAL PERSONNEL DOSSIER"
          title="Municipal Coordinator Profile"
          subtitle="Official personnel record, authorized command authorities, and Colombo Municipal Council administrative registry."
          ariaLabel="Municipal Coordinator Profile Banner"
          actions={
            <div className="profile-status-group">
              <span className="profile-verified-badge">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  <polyline points="9 12 11 14 15 10" />
                </svg>
                <span>Verified Officer</span>
              </span>

              <span className="profile-status-pill">
                <span className="profile-status-dot" />
                <span>Duty Roster: Active</span>
              </span>
            </div>
          }
        />

        {/* 5. Read-Only Administrative Advisory Notice */}
        <div className="profile-advisory-banner">
          <div className="profile-advisory-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
              <path d="M7 11V7a5 5 0 0 1 10 0v4" />
            </svg>
          </div>
          <div className="profile-advisory-body">
            <h4 className="profile-advisory-title">
              Centralized Municipal Registry — Read-Only Official Record
            </h4>
            <p className="profile-advisory-text">
              Municipal Operations Coordinator credentials and command assignments are governed centrally under the
              Colombo Municipal Council ICT & HR Administrative Directives. Direct self-service modifications are restricted
              to safeguard chain-of-command integrity and statutory audit trails. To request official contact number updates
              or duty roster reassignment, please submit an administrative memorandum to the City Secretariat.
            </p>
            <div className="profile-advisory-meta">
              <span className="profile-advisory-meta-item">
                <strong>Administrative Reference:</strong> CMC-ICT-AUTH-2026
              </span>
              <span className="profile-advisory-meta-item">•</span>
              <span className="profile-advisory-meta-item">
                <strong>Directorate:</strong> Engineering & Municipal Works
              </span>
              <span className="profile-advisory-meta-item">•</span>
              <span className="profile-advisory-meta-item">
                <strong>Internal Support Ext:</strong> 402 / 415
              </span>
            </div>
          </div>
        </div>

        {/* 6. Main Details Grid */}
        <div className="profile-grid-layout">
          {/* Card A: Officer Identification & Credentials */}
          <div className="profile-card profile-card-half">
            <div className="profile-card-header">
              <div className="profile-card-title-group">
                <div className="profile-card-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                    <circle cx="12" cy="7" r="4" />
                  </svg>
                </div>
                <div>
                  <h3 className="profile-card-title">Officer Identification</h3>
                  <p className="profile-card-subtitle">Credential records & authentication identifiers</p>
                </div>
              </div>
            </div>

            {/* Officer Hero Block */}
            <div className="officer-hero-block">
              <div className="officer-avatar-wrap">
                {effectiveUser.profileImageUrl ? (
                  <img
                    src={effectiveUser.profileImageUrl}
                    alt={officerName}
                    className="officer-avatar-img"
                  />
                ) : (
                  <div className="officer-avatar-initials">{initials}</div>
                )}
                <div className="officer-verified-seal" title="Verified Municipal Authority">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                </div>
              </div>

              <div className="officer-meta-block">
                <h3 className="officer-name">{officerName}</h3>
                <div className="officer-designation">Lead Operations & Dispatch Coordinator</div>
                <div className="officer-department">Directorate of Municipal Engineering & Works</div>
              </div>
            </div>

            {/* Details Table */}
            <div className="profile-details-table">
              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                    <line x1="16" y1="2" x2="16" y2="6" />
                    <line x1="8" y1="2" x2="8" y2="6" />
                    <line x1="3" y1="10" x2="21" y2="10" />
                  </svg>
                  Officer System ID
                </span>
                <span className="profile-detail-value">
                  <code className="profile-detail-code">{officerId}</code>
                  <button
                    type="button"
                    className={`profile-copy-btn ${copiedKey === 'id' ? 'copied' : ''}`}
                    onClick={() => handleCopy(officerId, 'id')}
                    title="Copy Officer ID"
                  >
                    {copiedKey === 'id' ? (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                    ) : (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                      </svg>
                    )}
                  </button>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                    <polyline points="22,6 12,13 2,6" />
                  </svg>
                  Government Email
                </span>
                <span className="profile-detail-value">
                  <span>{officerEmail}</span>
                  <button
                    type="button"
                    className={`profile-copy-btn ${copiedKey === 'email' ? 'copied' : ''}`}
                    onClick={() => handleCopy(officerEmail, 'email')}
                    title="Copy Email"
                  >
                    {copiedKey === 'email' ? (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                    ) : (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                      </svg>
                    )}
                  </button>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                  </svg>
                  Official Contact Phone
                </span>
                <span className="profile-detail-value">
                  <span>{officerPhone}</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                  </svg>
                  Access Role Classification
                </span>
                <span className="profile-detail-value">
                  <span style={{ color: 'var(--mw-forest)', fontWeight: 700 }}>ADMIN (Operational Command)</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                  Security Clearance Tier
                </span>
                <span className="profile-detail-value">
                  <span>Level 3 Incident Commander</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                  Command Station
                </span>
                <span className="profile-detail-value">
                  <span>Central Operations Desk — Town Hall</span>
                </span>
              </div>
            </div>
          </div>

          {/* Card B: Municipal Council Authority Details */}
          <div className="profile-card profile-card-half">
            <div className="profile-card-header">
              <div className="profile-card-title-group">
                <div className="profile-card-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M3 21h18M3 7v14M21 7v14M6 11h2M6 15h2M16 11h2M16 15h2M10 21v-4a2 2 0 0 1 4 0v4M4 7l8-4 8 4" />
                  </svg>
                </div>
                <div>
                  <h3 className="profile-card-title">Municipal Council Authority</h3>
                  <p className="profile-card-subtitle">Civic governance & administrative entity</p>
                </div>
              </div>
            </div>

            <div className="profile-details-table">
              <div className="profile-detail-row">
                <span className="profile-detail-label">Local Governing Body</span>
                <span className="profile-detail-value">
                  <span>Colombo Municipal Council (CMC)</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Official Council Name</span>
                <span className="profile-detail-value">
                  <span style={{ fontSize: '0.8125rem' }}>කොළඹ මහ නගර සභාව / கொழும்பு மாநகர சபை</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Civic Headquarters</span>
                <span className="profile-detail-value">
                  <span>Town Hall, F. R. Senanayake Mawatha, Colombo 07</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Supervising Ministry</span>
                <span className="profile-detail-value">
                  <span>Ministry of Public Administration & Local Government</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Administrative Wards</span>
                <span className="profile-detail-value">
                  <span>47 Wards across 5 Electoral Districts</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Urban Surface Area</span>
                <span className="profile-detail-value">
                  <span>37.31 km² Municipal Zone</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Council Operations Hotline</span>
                <span className="profile-detail-value">
                  <span>+94 11 268 4290 / +94 11 269 3151</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">National Citizen Helpline</span>
                <span className="profile-detail-value">
                  <span style={{ color: '#166534', fontWeight: 700 }}>1919 (Toll-Free 24/7)</span>
                </span>
              </div>

              <div className="profile-detail-row">
                <span className="profile-detail-label">Official Web Portal</span>
                <span className="profile-detail-value">
                  <a
                    href="https://colombo.mc.gov.lk"
                    target="_blank"
                    rel="noreferrer"
                    style={{ color: 'var(--mw-forest)', textDecoration: 'underline' }}
                  >
                    colombo.mc.gov.lk
                  </a>
                </span>
              </div>
            </div>
          </div>


          {/* Card D: Regional Depots & Operations Network */}
          <div className="profile-card profile-card-full">
            <div className="profile-card-header">
              <div className="profile-card-title-group">
                <div className="profile-card-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76" />
                  </svg>
                </div>
                <div>
                  <h3 className="profile-card-title">Regional Municipal Depots & Fleet Stations</h3>
                  <p className="profile-card-subtitle">
                    Permanent field depots operating under the coordinator's operational dispatch jurisdiction
                  </p>
                </div>
              </div>
            </div>

            <div className="depots-grid">
              {/* Depot 1: Drainage */}
              <div className="depot-card">
                <div className="depot-header">
                  <h4 className="depot-name">Central Colombo Depot</h4>
                  <span className="depot-badge drainage">Drainage</span>
                </div>
                <p className="depot-detail">
                  <span>Location:</span> <span className="depot-detail-value">Ward 07 (Cinnamon Gardens)</span>
                </p>
                <p className="depot-detail">
                  <span>Fleet Unit:</span> <span className="depot-detail-value">WP-LB-4091 (High-Pressure Jetter)</span>
                </p>
                <p className="depot-detail">
                  <span>Depot Direct:</span> <span className="depot-detail-value">+94 11 269 1122</span>
                </p>
              </div>

              {/* Depot 2: Road */}
              <div className="depot-card">
                <div className="depot-header">
                  <h4 className="depot-name">Central Colombo Depot</h4>
                  <span className="depot-badge road">Roads</span>
                </div>
                <p className="depot-detail">
                  <span>Location:</span> <span className="depot-detail-value">Ward 03 (Kollupitiya)</span>
                </p>
                <p className="depot-detail">
                  <span>Fleet Unit:</span> <span className="depot-detail-value">WP-GA-8112 (Asphalt Patching Unit)</span>
                </p>
                <p className="depot-detail">
                  <span>Depot Direct:</span> <span className="depot-detail-value">+94 11 257 3401</span>
                </p>
              </div>

              {/* Depot 3: Solid Waste */}
              <div className="depot-card">
                <div className="depot-header">
                  <h4 className="depot-name">North Colombo Depot</h4>
                  <span className="depot-badge waste">Waste</span>
                </div>
                <p className="depot-detail">
                  <span>Location:</span> <span className="depot-detail-value">Ward 12 (Kotahena)</span>
                </p>
                <p className="depot-detail">
                  <span>Fleet Unit:</span> <span className="depot-detail-value">WP-NA-2234 (Hydraulic Compactor)</span>
                </p>
                <p className="depot-detail">
                  <span>Depot Direct:</span> <span className="depot-detail-value">+94 11 243 5680</span>
                </p>
              </div>

              {/* Depot 4: Electrical */}
              <div className="depot-card">
                <div className="depot-header">
                  <h4 className="depot-name">Central Colombo Depot</h4>
                  <span className="depot-badge electrical">Electrical</span>
                </div>
                <p className="depot-detail">
                  <span>Location:</span> <span className="depot-detail-value">Ward 05 (Havelock Town)</span>
                </p>
                <p className="depot-detail">
                  <span>Fleet Unit:</span> <span className="depot-detail-value">WP-QA-5067 (Aerial Boom Lift)</span>
                </p>
                <p className="depot-detail">
                  <span>Depot Direct:</span> <span className="depot-detail-value">+94 11 258 7792</span>
                </p>
              </div>

              {/* Depot 5: Environment */}
              <div className="depot-card">
                <div className="depot-header">
                  <h4 className="depot-name">South Colombo Depot</h4>
                  <span className="depot-badge environment">Environment</span>
                </div>
                <p className="depot-detail">
                  <span>Location:</span> <span className="depot-detail-value">Ward 06 (Wellawatte)</span>
                </p>
                <p className="depot-detail">
                  <span>Fleet Unit:</span> <span className="depot-detail-value">WP-LA-3389 (Arboricultural Unit)</span>
                </p>
                <p className="depot-detail">
                  <span>Depot Direct:</span> <span className="depot-detail-value">+94 11 236 4415</span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
