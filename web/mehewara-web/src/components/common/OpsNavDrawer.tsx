import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ROUTES } from '../../routes/paths';
import { Icon } from '../../design-system/mehewara/Icon';
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
                  <Icon name="grid" size={18} color="currentColor" />
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
                  <Icon name="warning" size={18} color="currentColor" />
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Problems Board</span>
                  <span className="ops-drawer-item-desc">Consolidated municipal defects</span>
                </div>
              </div>
              {activePage === 'problems' && <span className="ops-drawer-active-dot" />}
            </button>

            {/* 3. Uncertain Reports Triage */}
            <button
              type="button"
              className={`ops-drawer-item ${activePage === 'uncertain-reports' ? 'active' : ''}`}
              onClick={() => handleNav(onNavigateToUncertainReports, ROUTES.UNCERTAIN_REPORTS)}
              aria-current={activePage === 'uncertain-reports' ? 'page' : undefined}
            >
              <div className="ops-drawer-item-left">
                <div className="ops-drawer-icon-wrap">
                  <Icon name="info" size={18} color="currentColor" />
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Uncertain Reports</span>
                  <span className="ops-drawer-item-desc">Ambiguous defect verification & triage</span>
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
                  <Icon name="problems" size={18} color="currentColor" />
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Dispatch Queue</span>
                  <span className="ops-drawer-item-desc">Priority scoring & crew assignment</span>
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
                  <Icon name="users" size={18} color="currentColor" />
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
                  <Icon name="work-orders" size={18} color="currentColor" />
                </div>
                <div className="ops-drawer-item-text">
                  <span className="ops-drawer-item-label">Work Orders</span>
                  <span className="ops-drawer-item-desc">Field execution & job telemetry</span>
                </div>
              </div>
              {activePage === 'work-orders' && <span className="ops-drawer-active-dot" />}
            </button>
          </div>
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
