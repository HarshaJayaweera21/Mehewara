import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ROUTES } from '../../routes/paths';
import mehewaraLogo from '../../assets/mehewara-logo.png';
import './OpsNavDrawer.css';

export type OpsNavPage =
  | 'dashboard'
  | 'problems'
  | 'uncertain-reports'
  | 'dispatch'
  | 'crews'
  | 'work-orders'
  | 'reports';

export interface OpsNavDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  activePage: OpsNavPage;
  pendingDispatchCount?: number;
  onNavigateToDashboard?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToUncertainReports?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
  onNavigateToWorkOrders?: () => void;
  onNavigateToReports?: () => void;
  showReportsLink?: boolean;
}

export const OpsNavDrawer: React.FC<OpsNavDrawerProps> = ({
  isOpen,
  onClose,
  activePage,
  pendingDispatchCount = 0,
  onNavigateToDashboard,
  onNavigateToProblems,
  onNavigateToUncertainReports,
  onNavigateToDispatch,
  onNavigateToCrews,
  onNavigateToWorkOrders,
  onNavigateToReports,
  showReportsLink = true,
}) => {
  const navigate = useNavigate();

  // Close on Escape & prevent background scrolling when open
  useEffect(() => {
    if (!isOpen) return;

    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);

    return () => {
      document.body.style.overflow = originalOverflow;
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onClose]);

  const handleNav = (customAction?: () => void, targetRoute?: string) => {
    onClose();
    if (customAction) {
      customAction();
    } else if (targetRoute) {
      navigate(targetRoute);
    }
  };

  return (
    <>
      {/* Backdrop Overlay */}
      <div
        className={`ops-drawer-overlay ${isOpen ? 'open' : ''}`}
        onClick={onClose}
        aria-hidden={!isOpen}
      />

      {/* Slide-out Navigation Drawer */}
      <aside
        className={`ops-drawer-panel ${isOpen ? 'open' : ''}`}
        role="dialog"
        aria-modal="true"
        aria-label="Operations Navigation Drawer"
      >
        {/* Drawer Brand Header */}
        <div className="ops-drawer-header">
          <div
            className="ops-drawer-brand"
            onClick={() => handleNav(onNavigateToDashboard, ROUTES.OPERATIONS)}
            role="button"
            tabIndex={0}
            style={{ cursor: 'pointer' }}
          >
            <img src={mehewaraLogo} alt="Mehewara Emblem" className="ops-drawer-logo" />
            <div className="ops-drawer-title-group">
              <span className="ops-drawer-title-sinhala">මෙහෙවර</span>
              <span className="ops-drawer-subtitle">Operations Suite</span>
            </div>
          </div>

          <button
            type="button"
            className="ops-drawer-close-btn"
            onClick={onClose}
            aria-label="Close navigation drawer"
            title="Close menu (Esc)"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        {/* Scrollable Navigation Items */}
        <div className="ops-drawer-body">
          {/* Section 1: Operations Workflows */}
          <div className="ops-drawer-section">
            <span className="ops-drawer-section-title">Operations Workflows</span>

            {/* 1. Dashboard Overview */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'dashboard' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToDashboard, ROUTES.OPERATIONS)}
              aria-current={activePage === 'dashboard' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="3" width="7" height="7" />
                    <rect x="14" y="3" width="7" height="7" />
                    <rect x="14" y="14" width="7" height="7" />
                    <rect x="3" y="14" width="7" height="7" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Operations Dashboard</span>
                  <span className="ops-drawer-item-desc">Live telemetry & stats overview</span>
                </div>
              </div>
              {activePage === 'dashboard' && <span className="ops-drawer-active-dot" />}
            </button>

            {/* 2. Problems Board */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'problems' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToProblems, ROUTES.PROBLEMS)}
              aria-current={activePage === 'problems' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="12" />
                    <line x1="12" y1="16" x2="12.01" y2="16" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Problems Board</span>
                  <span className="ops-drawer-item-desc">Consolidated municipal defects</span>
                </div>
              </div>
              {activePage === 'problems' && <span className="ops-drawer-active-dot" />}
            </button>

            {/* 3. Uncertain Reports Triage (Agent 2) */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'uncertain-reports' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToUncertainReports, ROUTES.UNCERTAIN_REPORTS)}
              aria-current={activePage === 'uncertain-reports' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Uncertain Reports</span>
                  <span className="ops-drawer-item-desc">Agent 2 human-in-the-loop triage</span>
                </div>
              </div>
              {activePage === 'uncertain-reports' && <span className="ops-drawer-active-dot" />}
            </button>

            {/* 4. Dispatch Queue */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'dispatch' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToDispatch, ROUTES.DISPATCH)}
              aria-current={activePage === 'dispatch' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polygon points="12 2 2 7 12 12 22 7 12 2" />
                    <polyline points="2 17 12 22 22 17" />
                    <polyline points="2 12 12 17 22 12" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Dispatch Queue</span>
                  <span className="ops-drawer-item-desc">Agent 3 prioritization & crew assignment</span>
                </div>
              </div>
              {pendingDispatchCount > 0 ? (
                <span className="ops-drawer-badge" title={`${pendingDispatchCount} pending recommendations`}>
                  {pendingDispatchCount}
                </span>
              ) : (
                activePage === 'dispatch' && <span className="ops-drawer-active-dot" />
              )}
            </button>

            {/* 5. Municipal Crews */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'crews' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToCrews, ROUTES.CREWS)}
              aria-current={activePage === 'crews' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Municipal Crews</span>
                  <span className="ops-drawer-item-desc">Squad directory & live availability</span>
                </div>
              </div>
              {activePage === 'crews' && <span className="ops-drawer-active-dot" />}
            </button>

            {/* 6. Work Orders */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'work-orders' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToWorkOrders, ROUTES.WORK_ORDERS)}
              aria-current={activePage === 'work-orders' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                    <line x1="16" y1="13" x2="8" y2="13" />
                    <line x1="16" y1="17" x2="8" y2="17" />
                    <polyline points="10 9 9 9 8 9" />
                  </svg>
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Work Orders</span>
                  <span className="ops-drawer-item-desc">Field execution & job telemetry</span>
                </div>
              </div>
              {activePage === 'work-orders' && <span className="ops-drawer-active-dot" />}
            </button>
          </div>

          {/* Section 2: Public & Resident Portals */}
          {showReportsLink && (
            <div className="ops-drawer-section">
              <span className="ops-drawer-section-title">Portals & Public</span>

              {/* Resident Reports Portal */}
              <button
                type="button"
                className={`ops-drawer-item ${activePage === 'reports' ? 'active' : ''}`}
                onClick={() => handleNav(onNavigateToReports, ROUTES.REPORTS)}
                aria-current={activePage === 'reports' ? 'page' : undefined}
              >
                <div className="ops-drawer-item-left">
                  <div className="ops-drawer-icon-wrap">
                    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                      <line x1="16" y1="13" x2="8" y2="13" />
                      <line x1="16" y1="17" x2="8" y2="17" />
                      <polyline points="10 9 9 9 8 9" />
                    </svg>
                  </div>
                  <div className="ops-drawer-item-text">
                    <span className="ops-drawer-item-label">Resident Reports</span>
                    <span className="ops-drawer-item-desc">Citizen defect intake & tracking</span>
                  </div>
                </div>
                {activePage === 'reports' && <span className="ops-drawer-active-dot" />}
              </button>
            </div>
          )}
        </div>

        {/* Drawer Footer */}
        <div className="ops-drawer-footer">
          <div className="ops-drawer-status-bar">
            <div className="ops-drawer-status-indicator">
              <span className="ops-drawer-pulse-dot" />
              <span>Live Operations</span>
            </div>
            <span className="ops-drawer-role-pill">Coordinator</span>
          </div>
          <span className="ops-drawer-hint">Press Esc or click outside to close</span>
        </div>
      </aside>
    </>
  );
};
