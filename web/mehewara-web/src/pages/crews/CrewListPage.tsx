import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { CrewListItem, CrewType, CrewStatus } from '../../types/crew';
import { getCrews } from '../../services/crewApi';
import { Header, HeroBanner, MetricsStrip } from '../../components/common';
import { OpsNavDrawer } from '../../components/common/OpsNavDrawer';
import { CrewDetailModal } from './components/CrewDetailModal';
import { ROUTES } from '../../routes/paths';
import './CrewListPage.css';

export interface CrewListPageProps {
  currentUser?: User | null;
  token?: string | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToReports?: () => void;
  onNavigateToWorkOrders?: (workOrderId?: string) => void;
}

const CREW_TYPES: (CrewType | 'ALL')[] = [
  'ALL',
  'DRAINAGE',
  'ROAD',
  'WASTE',
  'ELECTRICAL',
  'ENVIRONMENT',
];

const STATUSES: (CrewStatus | 'ALL')[] = ['ALL', 'AVAILABLE', 'BUSY'];

export const CrewListPage: React.FC<CrewListPageProps> = ({
  currentUser,
  token,
  onLogout,
  onOpenProfile,
  onNavigateToProblems,
  onNavigateToDispatch,
  onNavigateToReports,
  onNavigateToWorkOrders,
}) => {
  const navigate = useNavigate();
  const [isNavDrawerOpen, setIsNavDrawerOpen] = useState(false);

  const goToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));
  const goToDispatch = onNavigateToDispatch || (() => navigate(ROUTES.DISPATCH));
  const goToReports = onNavigateToReports || (() => navigate(ROUTES.REPORTS));
  const goToProfile = onOpenProfile || (() => navigate(ROUTES.PROFILE));
  const handleWorkOrders = onNavigateToWorkOrders || ((id?: string) => navigate(id ? `${ROUTES.WORK_ORDERS}?id=${id}` : ROUTES.WORK_ORDERS));

  const authToken = token || localStorage.getItem('mehewara_token') || '';

  const [crews, setCrews] = useState<CrewListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedCrewId, setSelectedCrewId] = useState<string | null>(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedType, setSelectedType] = useState<string>('ALL');
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL');
  const [viewLayout, setViewLayout] = useState<'grid' | 'table'>('grid');
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const fetchCrewsData = useCallback(async () => {
    if (!authToken) return;
    setIsLoading(true);
    setErrorMessage(null);

    try {
      const res = await getCrews(authToken, {
        crewType: selectedType !== 'ALL' ? selectedType : undefined,
        status: selectedStatus !== 'ALL' ? selectedStatus : undefined,
        search: searchQuery.trim() || undefined,
      });
      setCrews(res.items || []);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Unable to connect to municipal crews database.');
    } finally {
      setIsLoading(false);
    }
  }, [authToken, selectedType, selectedStatus, searchQuery]);

  useEffect(() => {
    fetchCrewsData();
  }, [fetchCrewsData, refreshTrigger]);

  // Operational metrics
  const metrics = useMemo(() => {
    const total = crews.length;
    const available = crews.filter((c) => c.status === 'AVAILABLE').length;
    const busy = crews.filter((c) => c.status === 'BUSY').length;
    const specializations = new Set(crews.map((c) => c.crewType)).size;

    return { total, available, busy, specializations };
  }, [crews]);

  return (
    <div className="crews-page-container">
      {/* 1. Global Navigation Header */}
      <Header
        currentUser={currentUser}
        onLogout={onLogout}
        onOpenProfile={goToProfile}
        onBrandClick={goToProblems}
        roleBadgeText="Municipal Coordinator"
        showMenuButton={true}
        onMenuClick={() => setIsNavDrawerOpen(prev => !prev)}
        isMenuOpen={isNavDrawerOpen}
      />

      <OpsNavDrawer
        isOpen={isNavDrawerOpen}
        onClose={() => setIsNavDrawerOpen(false)}
        activePage="crews"
        onNavigateToDashboard={() => navigate(ROUTES.OPERATIONS)}
        onNavigateToProblems={goToProblems}
        onNavigateToDispatch={goToDispatch}
        onNavigateToCrews={() => {}}
        onNavigateToWorkOrders={() => handleWorkOrders()}
        onNavigateToReports={goToReports}
      />

      <main className="crews-content-wrap">

        {/* 2. Operations Welcome Banner */}
        <HeroBanner
          badge="OPERATIONAL TELEMETRY"
          title="Municipal Response Crews Directory"
          subtitle="Real-time readiness telemetry, assigned wards, and active work orders for municipal field squads. Automated dispatch relies on live crew availability."
          ariaLabel="Municipal Crews Banner"
        />

        {/* 3. Operational Metrics Strip */}
        <MetricsStrip
          items={[
            {
              id: 'registered',
              label: 'Registered Squads',
              value: metrics.total,
              descriptor: 'Total active field units',
              hasPip: true,
            },
            {
              id: 'available',
              label: 'Available for Dispatch',
              value: metrics.available,
              descriptor: 'Standby at municipal depot',
            },
            {
              id: 'busy',
              label: 'Deployed on Missions',
              value: metrics.busy,
              descriptor: 'Active site remediation',
            },
            {
              id: 'specializations',
              label: 'Specializations',
              value: `${metrics.specializations} / 5`,
              descriptor: 'Drainage, Road, Waste, Electrical, Environment',
            },
          ]}
          ariaLabel="Key Crews Metrics"
        />

        {/* 4. Filter Toolbar */}
        <section className="crews-toolbar" aria-label="Filter Crews">
          <div className="crews-search-box">
            <svg className="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              className="crews-search-input"
              placeholder="Search squad name or crew lead..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              aria-label="Search municipal crews"
            />
          </div>

          <div className="crews-filters-group">
            {/* Specialization Filter */}
            <div className="crews-filter-wrap">
              <select
                className="crews-filter-select"
                value={selectedType}
                onChange={(e) => setSelectedType(e.target.value)}
                aria-label="Filter by Specialization"
              >
                {CREW_TYPES.map((type) => (
                  <option key={type} value={type}>
                    {type === 'ALL' ? 'Specialization: All' : type}
                  </option>
                ))}
              </select>
            </div>

            {/* Status Filter */}
            <div className="crews-filter-wrap">
              <select
                className="crews-filter-select"
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                aria-label="Filter by Status"
              >
                {STATUSES.map((st) => (
                  <option key={st} value={st}>
                    {st === 'ALL' ? 'Status: All' : st}
                  </option>
                ))}
              </select>
            </div>

            {(searchQuery.trim() !== '' || selectedType !== 'ALL' || selectedStatus !== 'ALL') && (
              <button
                type="button"
                className="crews-clear-filters-btn"
                onClick={() => {
                  setSearchQuery('');
                  setSelectedType('ALL');
                  setSelectedStatus('ALL');
                }}
              >
                Clear filters
              </button>
            )}

            <div className="crews-view-toggle" role="group" aria-label="Layout View Switcher">
              <button
                type="button"
                className={`crews-toggle-btn ${viewLayout === 'grid' ? 'active' : ''}`}
                onClick={() => setViewLayout('grid')}
                title="Grid Card View"
                aria-label="Grid Card View"
              >
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <rect x="3" y="3" width="7" height="7" />
                  <rect x="14" y="3" width="7" height="7" />
                  <rect x="14" y="14" width="7" height="7" />
                  <rect x="3" y="14" width="7" height="7" />
                </svg>
              </button>
              <button
                type="button"
                className={`crews-toggle-btn ${viewLayout === 'table' ? 'active' : ''}`}
                onClick={() => setViewLayout('table')}
                title="Table View"
                aria-label="Table View"
              >
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="8" y1="6" x2="21" y2="6" />
                  <line x1="8" y1="12" x2="21" y2="12" />
                  <line x1="8" y1="18" x2="21" y2="18" />
                  <line x1="3" y1="6" x2="3.01" y2="6" />
                  <line x1="3" y1="12" x2="3.01" y2="12" />
                  <line x1="3" y1="18" x2="3.01" y2="18" />
                </svg>
              </button>
            </div>

            <button
              type="button"
              className="crews-refresh-btn"
              onClick={() => setRefreshTrigger((prev) => prev + 1)}
              title="Refresh crews"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                <polyline points="23 4 23 10 17 10" />
                <polyline points="1 20 1 14 7 14" />
                <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
              </svg>
              <span>Refresh</span>
            </button>
          </div>
        </section>

        {errorMessage && (
          <div className="crews-error-banner">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <span>{errorMessage}</span>
          </div>
        )}

        {/* 5. Crews Grid */}
        <section className="crews-grid" aria-label="Municipal Crews Cards">
          {isLoading && (
            <div className="crews-skeleton-grid">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="crew-card skeleton-card">
                  <div className="skeleton-box" style={{ width: '40%', height: '14px', marginBottom: '12px' }} />
                  <div className="skeleton-box" style={{ width: '70%', height: '22px', marginBottom: '8px' }} />
                  <div className="skeleton-box" style={{ width: '50%', height: '14px', marginBottom: '18px' }} />
                  <div className="skeleton-box" style={{ width: '100%', height: '36px' }} />
                </div>
              ))}
            </div>
          )}

          {!isLoading && crews.length === 0 && (
            <div className="crews-empty-state">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#8F9995" strokeWidth="1.5">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
              </svg>
              <h3>No Crews Found</h3>
              <p>No municipal response crews matched your current filter selection.</p>
            </div>
          )}

          {!isLoading && crews.length > 0 && viewLayout === 'grid' && (
            <div className="crews-cards-container">
              {crews.map((crew) => (
                <article
                  key={crew.id}
                  className="crew-card"
                  onClick={() => setSelectedCrewId(crew.id)}
                >
                  <div className="crew-card-header">
                    <span className="crew-category-badge">
                      <span className="crew-badge-dot" />
                      {crew.crewType}
                    </span>
                    <div className={`crew-status-pill status-${crew.status.toLowerCase()}`}>
                      <span className="status-dot" />
                      <span>{crew.status}</span>
                    </div>
                  </div>

                  <h3 className="crew-card-title">{crew.name}</h3>

                  <div className="crew-card-details">
                    <div className="crew-detail-row">
                      <span className="detail-meta-label">Registry Ref:</span>
                      <span className="detail-meta-val font-mono">{crew.id.substring(0, 13)}...</span>
                    </div>
                    <div className="crew-detail-row">
                      <span className="detail-meta-label">Current Assignment:</span>
                      <span className="detail-meta-val">
                        {crew.activeWorkOrderId ? (
                          <span className="active-wo-tag">WO: {crew.activeWorkOrderId.substring(0, 8)}...</span>
                        ) : (
                          <span className="standby-tag">Standby / Available</span>
                        )}
                      </span>
                    </div>
                  </div>

                  <div className="crew-card-footer">
                    <button
                      type="button"
                      className="crew-view-profile-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedCrewId(crew.id);
                      }}
                    >
                      <span>View Specifications & Telemetry</span>
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                        <polyline points="9 18 15 12 9 6" />
                      </svg>
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}

          {!isLoading && crews.length > 0 && viewLayout === 'table' && (
            <div className="crews-table-container">
              <table className="crews-table">
                <thead>
                  <tr>
                    <th>Squad / Unit</th>
                    <th>Category</th>
                    <th>Operational Status</th>
                    <th>Current Assignment</th>
                    <th>Registry Ref</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {crews.map((crew) => (
                    <tr
                      key={crew.id}
                      onClick={() => setSelectedCrewId(crew.id)}
                    >
                      <td>
                        <div className="table-crew-name-cell">
                          <span className="table-crew-name">{crew.name}</span>
                          <span className="table-crew-specialization">{crew.crewType} SPECIALIZATION</span>
                        </div>
                      </td>
                      <td>
                        <span className="crew-category-badge">
                          <span className="crew-badge-dot" />
                          {crew.crewType}
                        </span>
                      </td>
                      <td>
                        <div className={`crew-status-pill status-${crew.status.toLowerCase()}`}>
                          <span className="status-dot" />
                          <span>{crew.status}</span>
                        </div>
                      </td>
                      <td>
                        {crew.activeWorkOrderId ? (
                          <span className="active-wo-tag">WO: {crew.activeWorkOrderId.substring(0, 8)}...</span>
                        ) : (
                          <span className="standby-tag">Standby</span>
                        )}
                      </td>
                      <td>
                        <span className="detail-meta-val font-mono">{crew.id.substring(0, 13)}...</span>
                      </td>
                      <td>
                        <button
                          type="button"
                          className="crew-view-profile-btn"
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedCrewId(crew.id);
                          }}
                        >
                          <span>Inspect</span>
                          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                            <polyline points="9 18 15 12 9 6" />
                          </svg>
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </main>

      {/* Crew Detail Modal */}
      {selectedCrewId && (
        <CrewDetailModal
          crewId={selectedCrewId}
          token={authToken}
          onClose={() => setSelectedCrewId(null)}
          onNavigateToWorkOrder={onNavigateToWorkOrders}
        />
      )}
    </div>
  );
};
