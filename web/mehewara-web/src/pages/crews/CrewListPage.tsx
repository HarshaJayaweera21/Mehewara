import React, { useState, useEffect, useMemo, useCallback } from 'react';
import type { User } from '../../types/auth';
import type { CrewListItem, CrewType, CrewStatus } from '../../types/crew';
import { getCrews } from '../../services/crewApi';
import { Header } from '../../components/common';
import { CrewDetailModal } from './components/CrewDetailModal';
import './CrewListPage.css';

export interface CrewListPageProps {
  currentUser?: User | null;
  token?: string | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToReports?: () => void;
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
}) => {
  const authToken = token || localStorage.getItem('mehewara_token') || '';

  const [crews, setCrews] = useState<CrewListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedCrewId, setSelectedCrewId] = useState<string | null>(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedType, setSelectedType] = useState<string>('ALL');
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL');
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
        onOpenProfile={onOpenProfile}
        roleBadgeText="Municipal Coordinator"
      />

      <main className="crews-content-wrap">
        {/* Operations Navigation Strip */}
        <nav className="operations-nav-strip" aria-label="Operations Navigation">
          <div className="nav-strip-left">
            <button
              type="button"
              className="nav-strip-btn"
              onClick={onNavigateToProblems}
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
              <span>Problems Board</span>
            </button>
            <span className="nav-strip-divider">/</span>
            <button
              type="button"
              className="nav-strip-btn"
              onClick={onNavigateToDispatch}
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polygon points="12 2 2 7 12 12 22 7 12 2" />
                <polyline points="2 17 12 22 22 17" />
                <polyline points="2 12 12 17 22 12" />
              </svg>
              <span>Dispatch Queue (Agent 3)</span>
            </button>
            <span className="nav-strip-divider">/</span>
            <button
              type="button"
              className="nav-strip-btn active"
              aria-current="page"
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
              <span>Municipal Crews</span>
            </button>
          </div>
          {onNavigateToReports && (
            <div className="nav-strip-right">
              <button
                type="button"
                className="nav-strip-subtle-link"
                onClick={onNavigateToReports}
              >
                Resident Reports Portal →
              </button>
            </div>
          )}
        </nav>

        {/* 2. Operations Welcome Banner */}
        <section className="crews-welcome-banner" aria-label="Municipal Crews Banner">
          <div className="crews-banner-content">
            <span className="banner-agent-badge">Operational Telemetry</span>
            <h1 className="crews-banner-heading">Municipal Response Crews Directory</h1>
            <p className="crews-banner-sub">
              Real-time readiness telemetry, assigned wards, and active work orders for municipal field squads. Automated dispatch relies on live crew availability.
            </p>
          </div>
        </section>

        {/* 3. Operational Metrics Strip */}
        <section className="crews-metrics-strip" aria-label="Key Crews Metrics">
          <div className="crews-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Registered Squads</span>
              <span className="metric-mint-pip" title="Full Municipal Capacity" />
            </div>
            <div className="metric-value">{metrics.total}</div>
            <div className="metric-descriptor">Total active field units</div>
          </div>

          <div className="crews-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Available for Dispatch</span>
            </div>
            <div className="metric-value">{metrics.available}</div>
            <div className="metric-descriptor">Standby at municipal depot</div>
          </div>

          <div className="crews-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Deployed on Missions</span>
            </div>
            <div className="metric-value">{metrics.busy}</div>
            <div className="metric-descriptor">Active site remediation</div>
          </div>

          <div className="crews-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Specializations</span>
            </div>
            <div className="metric-value">{metrics.specializations} / 5</div>
            <div className="metric-descriptor">Drainage, Road, Waste, Electrical, Environment</div>
          </div>
        </section>

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

          {!isLoading && crews.length > 0 && (
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
        </section>
      </main>

      {/* Crew Detail Modal */}
      {selectedCrewId && (
        <CrewDetailModal
          crewId={selectedCrewId}
          token={authToken}
          onClose={() => setSelectedCrewId(null)}
        />
      )}
    </div>
  );
};
