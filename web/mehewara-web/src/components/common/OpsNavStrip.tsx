import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ROUTES } from '../../routes/paths';
import './OpsNavStrip.css';

export type OpsNavPage = 'dashboard' | 'problems' | 'dispatch' | 'crews' | 'work-orders' | 'reports';

export interface OpsNavStripProps {
  activePage: OpsNavPage;
  pendingDispatchCount?: number;
  onNavigateToDashboard?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
  onNavigateToWorkOrders?: () => void;
  onNavigateToReports?: () => void;
  showReportsLink?: boolean;
}

export const OpsNavStrip: React.FC<OpsNavStripProps> = ({
  activePage,
  pendingDispatchCount = 0,
  onNavigateToDashboard,
  onNavigateToProblems,
  onNavigateToDispatch,
  onNavigateToCrews,
  onNavigateToWorkOrders,
  onNavigateToReports,
  showReportsLink = true,
}) => {
  let navigate: (to: string) => void = () => {};
  try {
    navigate = useNavigate();
  } catch {
    // Graceful fallback for non-router tests
  }

  const goToDashboard = onNavigateToDashboard || (() => navigate(ROUTES.OPERATIONS));
  const goToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));
  const goToDispatch = onNavigateToDispatch || (() => navigate(ROUTES.DISPATCH));
  const goToCrews = onNavigateToCrews || (() => navigate(ROUTES.CREWS));
  const goToWorkOrders = onNavigateToWorkOrders || (() => navigate(ROUTES.WORK_ORDERS));
  const goToReports = onNavigateToReports || (() => navigate(ROUTES.REPORTS));

  return (
    <nav className="operations-nav-strip" aria-label="Operations Navigation">
      <div className="nav-strip-left">
        {/* Dashboard */}
        <button
          type="button"
          className={`nav-strip-btn ${activePage === 'dashboard' ? 'active' : ''}`}
          onClick={goToDashboard}
          aria-current={activePage === 'dashboard' ? 'page' : undefined}
          title="Operations Overview Dashboard"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="7" height="7" />
            <rect x="14" y="3" width="7" height="7" />
            <rect x="14" y="14" width="7" height="7" />
            <rect x="3" y="14" width="7" height="7" />
          </svg>
          <span>Dashboard</span>
        </button>

        <span className="nav-strip-divider">/</span>

        {/* Problems */}
        <button
          type="button"
          className={`nav-strip-btn ${activePage === 'problems' ? 'active' : ''}`}
          onClick={goToProblems}
          aria-current={activePage === 'problems' ? 'page' : undefined}
          title="Municipal Problems Board"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          <span>Problems Board</span>
        </button>

        <span className="nav-strip-divider">/</span>

        {/* Dispatch */}
        <button
          type="button"
          className={`nav-strip-btn ${activePage === 'dispatch' ? 'active' : ''}`}
          onClick={goToDispatch}
          aria-current={activePage === 'dispatch' ? 'page' : undefined}
          title="Open Dispatch & Recommendations Queue"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polygon points="12 2 2 7 12 12 22 7 12 2" />
            <polyline points="2 17 12 22 22 17" />
            <polyline points="2 12 12 17 22 12" />
          </svg>
          <span>Dispatch Queue</span>
          {pendingDispatchCount > 0 && (
            <span className="nav-strip-counter-pill">{pendingDispatchCount}</span>
          )}
        </button>

        <span className="nav-strip-divider">/</span>

        {/* Crews */}
        <button
          type="button"
          className={`nav-strip-btn ${activePage === 'crews' ? 'active' : ''}`}
          onClick={goToCrews}
          aria-current={activePage === 'crews' ? 'page' : undefined}
          title="View Municipal Crew Directory & Readiness"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span>Municipal Crews</span>
        </button>

        <span className="nav-strip-divider">/</span>

        {/* Work Orders */}
        <button
          type="button"
          className={`nav-strip-btn ${activePage === 'work-orders' ? 'active' : ''}`}
          onClick={goToWorkOrders}
          aria-current={activePage === 'work-orders' ? 'page' : undefined}
          title="Municipal Work Orders & Job Tracking"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
            <polyline points="10 9 9 9 8 9" />
          </svg>
          <span>Work Orders</span>
        </button>
      </div>

      {showReportsLink && (
        <div className="nav-strip-right">
          <button
            type="button"
            className="nav-strip-subtle-link"
            onClick={goToReports}
          >
            Resident Reports Portal →
          </button>
        </div>
      )}
    </nav>
  );
};
