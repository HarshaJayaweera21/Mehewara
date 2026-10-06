import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ROUTES } from '../../routes/paths';
import { Icon } from '../../design-system/mehewara/Icon';
import './OpsNavStrip.css';

import type { OpsNavPage } from './OpsNavDrawer';
export type { OpsNavPage };

export interface OpsNavStripProps {
  activePage: OpsNavPage;
  pendingDispatchCount?: number;
  onNavigateToDashboard?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
  onNavigateToWorkOrders?: () => void;
}

export const OpsNavStrip: React.FC<OpsNavStripProps> = ({
  activePage,
  pendingDispatchCount = 0,
  onNavigateToDashboard,
  onNavigateToProblems,
  onNavigateToDispatch,
  onNavigateToCrews,
  onNavigateToWorkOrders,
}) => {
  const navigate = useNavigate();

  const goToDashboard = onNavigateToDashboard || (() => navigate(ROUTES.OPERATIONS));
  const goToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));
  const goToDispatch = onNavigateToDispatch || (() => navigate(ROUTES.DISPATCH));
  const goToCrews = onNavigateToCrews || (() => navigate(ROUTES.CREWS));
  const goToWorkOrders = onNavigateToWorkOrders || (() => navigate(ROUTES.WORK_ORDERS));

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
          <Icon name="grid" size={15} color="currentColor" />
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
          <Icon name="warning" size={15} color="currentColor" />
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
          <Icon name="problems" size={15} color="currentColor" />
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
          <Icon name="users" size={15} color="currentColor" />
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
          <Icon name="work-orders" size={15} color="currentColor" />
          <span>Work Orders</span>
        </button>
      </div>
    </nav>
  );
};
