import React, { useState, useRef, useEffect } from 'react';
import type { User } from '../../types/auth';
import mehewaraLogo from '../../assets/mehewara-logo.png';
import './Header.css';

export interface HeaderProps {
  currentUser?: User | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onBrandClick?: () => void;
  onLoginClick?: () => void;
  roleBadgeText?: string;
  className?: string;
}

export const Header: React.FC<HeaderProps> = ({
  currentUser,
  onLogout,
  onOpenProfile,
  onBrandClick,
  onLoginClick,
  roleBadgeText = 'Municipal Coordinator',
  className = '',
}) => {
  const [isProfileMenuOpen, setIsProfileMenuOpen] = useState(false);
  const profileMenuRef = useRef<HTMLDivElement>(null);

  // Close profile dropdown when clicking outside or pressing Escape
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (profileMenuRef.current && !profileMenuRef.current.contains(event.target as Node)) {
        setIsProfileMenuOpen(false);
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setIsProfileMenuOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

  return (
    <header className={`app-header ${className}`.trim()}>
      {/* Brand Identity: Logo Image + Sinhala Title */}
      <div 
        className="header-brand" 
        onClick={onBrandClick} 
        role={onBrandClick ? 'button' : undefined}
        tabIndex={onBrandClick ? 0 : undefined}
      >
        <img 
          src={mehewaraLogo} 
          alt="Mehewara Logo" 
          className="header-brand-logo" 
        />
        <div>
          <div className="header-brand-name">මෙහෙවර</div>
        </div>
      </div>

      {/* Top Right: Profile Icon (Logged in) or Sign In / Sign Up button (Guest) */}
      {currentUser ? (
        <div className="header-profile-wrap" ref={profileMenuRef}>
          <button
            type="button"
            className={`header-profile-trigger ${isProfileMenuOpen ? 'active' : ''}`}
            onClick={() => setIsProfileMenuOpen((prev) => !prev)}
            aria-haspopup="true"
            aria-expanded={isProfileMenuOpen}
            title="User Account Menu"
          >
          <div className="header-profile-avatar">
            {currentUser?.profileImageUrl ? (
              <img src={currentUser.profileImageUrl} alt="" className="header-avatar-img" />
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            )}
          </div>
          <svg
            className={`header-profile-chevron ${isProfileMenuOpen ? 'rotated' : ''}`}
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
          >
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </button>

        {isProfileMenuOpen && (
          <div className="header-profile-dropdown" role="menu">
            <div className="profile-dropdown-header">
              <div className="dropdown-user-name">{currentUser?.name || 'Municipal Coordinator'}</div>
              <div className="dropdown-user-role-badge">{roleBadgeText}</div>
              {currentUser?.email && (
                <div className="dropdown-user-email">{currentUser.email}</div>
              )}
            </div>

            <div className="profile-dropdown-divider" />

            <div className="profile-dropdown-actions">
              {onOpenProfile && (
                <button
                  type="button"
                  className="profile-dropdown-item"
                  onClick={() => {
                    setIsProfileMenuOpen(false);
                    onOpenProfile();
                  }}
                  role="menuitem"
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                    <circle cx="12" cy="7" r="4" />
                  </svg>
                  <span>View Profile</span>
                </button>
              )}

              {onLogout && (
                <button
                  type="button"
                  className="profile-dropdown-item logout-item"
                  onClick={() => {
                    setIsProfileMenuOpen(false);
                    onLogout();
                  }}
                  role="menuitem"
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                    <polyline points="16 17 21 12 16 7" />
                    <line x1="21" y1="12" x2="9" y2="12" />
                  </svg>
                  <span>Logout</span>
                </button>
              )}
            </div>
          </div>
        )}
      </div>
      ) : (
        <div className="header-auth-wrap">
          <button
            type="button"
            className="header-auth-btn"
            onClick={onLoginClick}
            title="Sign in or create a resident account"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
            <span>Sign In / Sign Up</span>
          </button>
        </div>
      )}
    </header>
  );
};
