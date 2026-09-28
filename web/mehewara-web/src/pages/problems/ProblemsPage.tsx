import React, { useState, useEffect, useMemo } from 'react';
import type { User } from '../../types/auth';
import type {
  ProblemResponse,
  ProblemCategory,
  ProblemPriority,
  ProblemStatus,
} from '../../types/problems';
import { getProblems, getUncertainReports } from '../../services/problemApi';
import { getRecommendations } from '../../services/dispatchApi';
import { Header } from '../../components/common';
import { CoordinatorWelcomeBanner } from './CoordinatorWelcomeBanner';
import { ProblemDetailModal } from './ProblemDetailModal';
import './ProblemsPage.css';

export interface ProblemsPageProps {
  currentUser?: User | null;
  token?: string | null;
  onLogout?: () => void;
  onNavigateToReports?: () => void;
  onOpenProfile?: () => void;
  onNavigateToLanding?: () => void;
  onSelectProblem?: (problemId: string) => void;
  onNavigateToUncertainReports?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
}

const CATEGORIES: (ProblemCategory | 'ALL')[] = [
  'ALL',
  'DRAINAGE',
  'ROAD',
  'WASTE',
  'ELECTRICAL',
  'ENVIRONMENT',
];

const PRIORITIES: (ProblemPriority | 'ALL')[] = [
  'ALL',
  'CRITICAL',
  'HIGH',
  'MEDIUM',
  'LOW',
];

const STATUSES: (ProblemStatus | 'ALL')[] = [
  'ALL',
  'IDENTIFIED',
  'ASSIGNED',
  'IN_PROGRESS',
  'RESOLVED',
];

export const ProblemsPage: React.FC<ProblemsPageProps> = ({
  currentUser,
  token,
  onLogout,
  onNavigateToReports,
  onOpenProfile,
  onNavigateToLanding,
  onSelectProblem,
  onNavigateToUncertainReports,
  onNavigateToDispatch,
  onNavigateToCrews,
}) => {
  // Search and filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('ALL');
  const [selectedPriority, setSelectedPriority] = useState<string>('ALL');
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 5;

  // Real backend data states
  const [problems, setProblems] = useState<ProblemResponse[]>([]);
  const [allProblemsForMetrics, setAllProblemsForMetrics] = useState<ProblemResponse[]>([]);
  const [uncertainCount, setUncertainCount] = useState<number>(0);
  const [pendingDispatchCount, setPendingDispatchCount] = useState<number>(0);
  const [totalResults, setTotalResults] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [activeToast, setActiveToast] = useState<string | null>(null);
  const [retryTrigger, setRetryTrigger] = useState(0);
  const [selectedProblemId, setSelectedProblemId] = useState<string | null>(null);

  // Fetch count of uncertain reports requiring coordinator review
  useEffect(() => {
    let ignore = false;
    const authToken = token || localStorage.getItem('mehewara_token') || '';
    if (!authToken) return;
    getUncertainReports(authToken)
      .then((data) => {
        if (!ignore && data) {
          setUncertainCount(data.length);
        }
      })
      .catch(() => {
        // Silently catch if not authenticated or error
      });

    return () => {
      ignore = true;
    };
  }, [token, retryTrigger]);

  // Fetch count of pending dispatch recommendations requiring coordinator review
  useEffect(() => {
    let ignore = false;
    const authToken = token || localStorage.getItem('mehewara_token') || '';
    getRecommendations(authToken)
      .then((data) => {
        if (!ignore && data?.items) {
          const pending = data.items.filter((r) => !r.reviewDecision).length;
          setPendingDispatchCount(pending);
        }
      })
      .catch(() => {
        // Silently catch
      });

    return () => {
      ignore = true;
    };
  }, [token, retryTrigger]);

  // Fetch real problem records from backend API
  useEffect(() => {
    let ignore = false;
    setIsLoading(true);
    setErrorMessage(null);

    const authToken = token || localStorage.getItem('mehewara_token') || '';

    // 1. Fetch paginated and filtered problems ordered by priority
    getProblems(authToken, {
      page: currentPage,
      pageSize,
      category: selectedCategory !== 'ALL' ? selectedCategory : undefined,
      priority: selectedPriority !== 'ALL' ? selectedPriority : undefined,
      status: selectedStatus !== 'ALL' ? selectedStatus : undefined,
      search: searchQuery.trim() || undefined,
      sortBy: 'priority',
      sortDirection: 'desc',
    })
      .then((res) => {
        if (!ignore) {
          const PRIORITY_ORDER: Record<string, number> = {
            CRITICAL: 4,
            HIGH: 3,
            MEDIUM: 2,
            LOW: 1,
          };
          const sorted = [...(res.items || [])].sort((a, b) => {
            const pA = PRIORITY_ORDER[(a.priority || '').toUpperCase()] || 0;
            const pB = PRIORITY_ORDER[(b.priority || '').toUpperCase()] || 0;
            if (pB !== pA) return pB - pA;
            return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
          });
          setProblems(sorted);
          setTotalResults(res.totalItems || 0);
          setTotalPages(Math.max(1, res.totalPages || 1));
          setIsLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!ignore) {
          setErrorMessage(err instanceof Error ? err.message : 'Unable to connect to municipal operations backend.');
          setProblems([]);
          setTotalResults(0);
          setIsLoading(false);
        }
      });

    // 2. Fetch overall dataset for operational metrics strip
    getProblems(authToken, {
      page: 1,
      pageSize: 100,
    })
      .then((res) => {
        if (!ignore && res?.items) {
          setAllProblemsForMetrics(res.items);
        }
      })
      .catch(() => {
        // Silently ignore metrics-only fetch failure
      });

    return () => {
      ignore = true;
    };
  }, [
    token,
    currentPage,
    selectedCategory,
    selectedPriority,
    selectedStatus,
    searchQuery,
    retryTrigger,
  ]);

  // Handle toast notification auto-hide
  useEffect(() => {
    if (activeToast) {
      const timer = setTimeout(() => setActiveToast(null), 4000);
      return () => clearTimeout(timer);
    }
  }, [activeToast]);

  const hasActiveFilters = Boolean(
    searchQuery.trim() !== '' ||
      selectedCategory !== 'ALL' ||
      selectedPriority !== 'ALL' ||
      selectedStatus !== 'ALL'
  );

  const handleClearFilters = () => {
    setSearchQuery('');
    setSelectedCategory('ALL');
    setSelectedPriority('ALL');
    setSelectedStatus('ALL');
    setCurrentPage(1);
  };

  // Operational metrics calculated dynamically from real backend problems
  const metrics = useMemo(() => {
    const dataset = allProblemsForMetrics.length > 0 ? allProblemsForMetrics : problems;

    const totalActive = dataset.filter((p) => {
      const s = (p.status || '').toUpperCase();
      return s !== 'RESOLVED' && s !== 'CLOSED';
    }).length;

    const highCritical = dataset.filter((p) => {
      const pr = (p.priority || '').toUpperCase();
      return pr === 'HIGH' || pr === 'CRITICAL';
    }).length;

    const inProgress = dataset.filter((p) => {
      const s = (p.status || '').toUpperCase();
      return s === 'IN_PROGRESS';
    }).length;

    const linkedReports = dataset.reduce(
      (sum, p) => sum + (p.relatedReportCount || 0),
      0
    );

    return {
      totalActive,
      highCritical,
      inProgress,
      linkedReports,
    };
  }, [allProblemsForMetrics, problems]);

  const handleCardClick = (problemId: string) => {
    setSelectedProblemId(problemId);
    if (onSelectProblem) {
      onSelectProblem(problemId);
    }
  };

  // Render priority badge with restrained semantic styling
  const renderPriorityBadge = (priority: string | null) => {
    const p = (priority || 'LOW').toUpperCase();
    let priorityClass = 'priority-low';
    if (p === 'CRITICAL') priorityClass = 'priority-critical';
    else if (p === 'HIGH') priorityClass = 'priority-high';
    else if (p === 'MEDIUM') priorityClass = 'priority-medium';

    return (
      <span className={`problem-priority-badge ${priorityClass}`}>
        {p}
      </span>
    );
  };

  // Render status indicator with dot and uppercase label
  const renderStatusIndicator = (status: string) => {
    const s = (status || 'IDENTIFIED').toUpperCase();
    let statusClass = 'status-identified';
    let label = 'IDENTIFIED';

    if (s === 'IN_PROGRESS') {
      statusClass = 'status-in_progress';
      label = 'IN PROGRESS';
    } else if (s === 'ASSIGNED') {
      statusClass = 'status-assigned';
      label = 'ASSIGNED';
    } else if (s === 'RESOLVED') {
      statusClass = 'status-resolved';
      label = 'RESOLVED';
    } else if (s === 'AWAITING_ASSIGNMENT') {
      statusClass = 'status-assigned';
      label = 'AWAITING ASSIGNMENT';
    }

    return (
      <span className={`problem-status-indicator ${statusClass}`}>
        <span className="status-dot" aria-hidden="true" />
        <span>{label}</span>
      </span>
    );
  };

  return (
    <div className="problems-dashboard-container">
      <div className="problems-content-wrap">
        
        {/* Navigation Bar (Extracted Reusable Header) */}
        <Header
          currentUser={currentUser}
          onLogout={onLogout}
          onOpenProfile={onOpenProfile}
          onBrandClick={onNavigateToLanding}
        />

        {/* 1. Coordinator Welcome Banner (Stitch Generated with Real Time Greeting) */}
        <CoordinatorWelcomeBanner roleName="Coordinator" activeProblemsCount={metrics.totalActive} />

        {/* 1.5. Coordinator Triage Alert Banner (Agent 2 HITL Queue) */}
        {uncertainCount > 0 && onNavigateToUncertainReports && (
          <div
            className="problems-uncertain-alert-banner"
            onClick={onNavigateToUncertainReports}
            role="button"
            tabIndex={0}
          >
            <div className="uncertain-alert-left">
              <div className="uncertain-alert-icon-wrap">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.3">
                  <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                  <line x1="12" y1="9" x2="12" y2="13" />
                  <line x1="12" y1="17" x2="12.01" y2="17" />
                </svg>
              </div>
              <div className="uncertain-alert-body">
                <div className="uncertain-alert-title-row">
                  <span className="uncertain-alert-title">
                    {uncertainCount} Report{uncertainCount > 1 ? 's' : ''} Require Coordinator Review
                  </span>
                  <span className="uncertain-alert-badge">Agent 2 Human-in-the-Loop</span>
                </div>
                <p className="uncertain-alert-desc">
                  AI consolidation flagged borderline or ambiguous citizen defect submissions. Open triage to inspect evidence, manually link to existing problems, or create new problem records.
                </p>
              </div>
            </div>
            <button
              type="button"
              className="uncertain-alert-cta-btn"
              onClick={(e) => {
                e.stopPropagation();
                onNavigateToUncertainReports();
              }}
            >
              <span>Review Uncertain Reports</span>
              <span className="uncertain-cta-count">{uncertainCount}</span>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </button>
          </div>
        )}

        {/* 2. Top Metrics Strip (Unified White Surface with Dividers) */}
        <section className="problems-metrics-strip" aria-label="Key Operational Metrics">
          <div className="problems-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Active Problems</span>
              <span className="metric-mint-pip" aria-hidden="true" title="Operational Priority Indicator" />
            </div>
            <div className="metric-value">{metrics.totalActive}</div>
            <div className="metric-descriptor">Across municipal wards</div>
          </div>

          <div className="problems-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">High / Critical</span>
            </div>
            <div className="metric-value">{metrics.highCritical}</div>
            <div className="metric-descriptor">Requiring urgent crew dispatch</div>
          </div>

          <div className="problems-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">In Progress</span>
            </div>
            <div className="metric-value">{metrics.inProgress}</div>
            <div className="metric-descriptor">Active site remediation</div>
          </div>

          <div className="problems-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Linked Reports</span>
            </div>
            <div className="metric-value">{metrics.linkedReports}</div>
            <div className="metric-descriptor">Consolidated resident submissions</div>
          </div>
        </section>

        {/* 3. Problems Section (Title & Filter / Search Toolbar) */}
        <div className="problems-search-filter-section">
          <div className="problems-section-header">
            <h2 className="problems-section-title">Problems</h2>
          </div>

          <section className="problems-toolbar" aria-label="Filter and Search Problems">
            <div className="problems-search-box">
              <svg className="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                className="problems-search-input"
                placeholder="Search problems or addresses..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value);
                  setCurrentPage(1);
                }}
                aria-label="Search problems or addresses"
              />
            </div>

            <div className="problems-filters-group">
              {/* Category Dropdown */}
              <div className="problems-filter-select-wrap">
                <select
                  className="problems-filter-select"
                  value={selectedCategory}
                  onChange={(e) => {
                    setSelectedCategory(e.target.value);
                    setCurrentPage(1);
                  }}
                  aria-label="Filter by Category"
                >
                  {CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat === 'ALL' ? 'Category: All' : cat}
                    </option>
                  ))}
                </select>
                <svg className="select-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <polyline points="6 9 12 15 18 9" />
                </svg>
              </div>

              {/* Priority Dropdown */}
              <div className="problems-filter-select-wrap">
                <select
                  className="problems-filter-select"
                  value={selectedPriority}
                  onChange={(e) => {
                    setSelectedPriority(e.target.value);
                    setCurrentPage(1);
                  }}
                  aria-label="Filter by Priority"
                >
                  {PRIORITIES.map((pri) => (
                    <option key={pri} value={pri}>
                      {pri === 'ALL' ? 'Priority: All' : pri}
                    </option>
                  ))}
                </select>
                <svg className="select-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <polyline points="6 9 12 15 18 9" />
                </svg>
              </div>

              {/* Status Dropdown */}
              <div className="problems-filter-select-wrap">
                <select
                  className="problems-filter-select"
                  value={selectedStatus}
                  onChange={(e) => {
                    setSelectedStatus(e.target.value);
                    setCurrentPage(1);
                  }}
                  aria-label="Filter by Status"
                >
                  {STATUSES.map((st) => (
                    <option key={st} value={st}>
                      {st === 'ALL' ? 'Status: All' : st.replace('_', ' ')}
                    </option>
                  ))}
                </select>
                <svg className="select-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <polyline points="6 9 12 15 18 9" />
                </svg>
              </div>

              {/* Clear Filters (Visible only when filters/search active) */}
              {hasActiveFilters && (
                <button
                  type="button"
                  className="problems-clear-filters-btn"
                  onClick={handleClearFilters}
                  title="Reset all search queries and dropdown filters"
                >
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <line x1="18" y1="6" x2="6" y2="18" />
                    <line x1="6" y1="6" x2="18" y2="18" />
                  </svg>
                  Clear filters
                </button>
              )}
            </div>
          </section>
        </div>

        {/* 4. Results Header */}
        <div className="problems-results-header">
          <h2 className="results-section-title">
            <span>Problems</span>
          </h2>
          <div className="problems-results-header-actions">
            {onNavigateToUncertainReports && (
              <button
                type="button"
                className="problems-uncertain-nav-btn"
                onClick={onNavigateToUncertainReports}
                title="Review citizen reports flagged by Agent 2 as uncertain"
              >
                <span className="uncertain-nav-dot" />
                <span>Uncertain Reports</span>
                {uncertainCount > 0 && (
                  <span className="uncertain-nav-badge">{uncertainCount}</span>
                )}
              </button>
            )}
            {onNavigateToDispatch && (
              <button
                type="button"
                className="problems-dispatch-nav-btn"
                onClick={onNavigateToDispatch}
                title="Open Agent 3 Dispatch Queue & Recommendation Authorizations"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <polygon points="12 2 2 7 12 12 22 7 12 2" />
                  <polyline points="2 17 12 22 22 17" />
                  <polyline points="2 12 12 17 22 12" />
                </svg>
                <span>Dispatch Queue</span>
                {pendingDispatchCount > 0 && (
                  <span className="dispatch-nav-badge">{pendingDispatchCount}</span>
                )}
              </button>
            )}
            {onNavigateToCrews && (
              <button
                type="button"
                className="problems-crews-nav-btn"
                onClick={onNavigateToCrews}
                title="Open Municipal Response Crews Directory"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                </svg>
                <span>Crews</span>
              </button>
            )}
            <div className="results-count-pill">
              {isLoading
                ? 'Loading...'
                : totalResults === 0
                ? 'No problems found'
                : `${totalResults} ${totalResults === 1 ? 'result' : 'results'}`}
            </div>
          </div>
        </div>

        {/* 5. Problems Grid & Real Backend States */}

        {/* STATE A: Loading Skeleton (Rectangular Cards) */}
        {isLoading && (
          <div className="problems-grid" aria-busy="true" aria-label="Loading problems from backend">
            {[1, 2, 3, 4, 5].map((idx) => (
              <div key={idx} className="problem-card problem-card-rectangular skeleton-card">
                <div className="problem-card-main-col">
                  <div className="problem-card-top-row">
                    <div className="problem-badges-wrap">
                      <div className="skeleton-box skeleton-badge" />
                      <div className="skeleton-box skeleton-category" />
                    </div>
                  </div>
                  <div className="problem-card-body">
                    <div className="skeleton-box skeleton-title-1" style={{ width: '60%', height: '18px' }} />
                    <div className="skeleton-box skeleton-desc-1" style={{ width: '92%', height: '14px' }} />
                  </div>
                  <div className="problem-card-meta">
                    <div className="skeleton-box skeleton-meta-line" style={{ width: '45%', height: '13px' }} />
                  </div>
                </div>
                <div className="problem-card-action-col">
                  <div className="skeleton-box skeleton-status" style={{ width: '100px', height: '24px' }} />
                  <div className="skeleton-box skeleton-action" style={{ width: '110px', height: '32px' }} />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* STATE B: Real Backend Error State */}
        {!isLoading && errorMessage && (
          <div className="problems-grid">
            <div className="problems-state-surface" role="alert">
              <div className="state-icon-circle">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
              </div>
              <h3 className="state-title">We couldn't load problems</h3>
              <p className="state-description">
                {errorMessage}
              </p>
              <button
                type="button"
                className="state-action-btn"
                onClick={() => setRetryTrigger((c) => c + 1)}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
                </svg>
                Try again
              </button>
            </div>
          </div>
        )}

        {/* STATE C: Real Empty State - No problems created yet */}
        {!isLoading && !errorMessage && totalResults === 0 && !hasActiveFilters && (
          <div className="problems-grid">
            <div className="problems-state-surface">
              <div className="state-icon-circle">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
                </svg>
              </div>
              <h3 className="state-title">No problems yet</h3>
              <p className="state-description">
                Problems created from resident reports will appear here.
              </p>
              {onNavigateToReports && (
                <button
                  type="button"
                  className="state-action-secondary-btn"
                  onClick={onNavigateToReports}
                >
                  View Resident Reports
                </button>
              )}
            </div>
          </div>
        )}

        {/* STATE D: Real Empty State - Filter/Search produced 0 results */}
        {!isLoading && !errorMessage && totalResults === 0 && hasActiveFilters && (
          <div className="problems-grid">
            <div className="problems-state-surface">
              <div className="state-icon-circle">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="11" cy="11" r="8" />
                  <line x1="21" y1="21" x2="16.65" y2="16.65" />
                  <line x1="8" y1="11" x2="14" y2="11" />
                </svg>
              </div>
              <h3 className="state-title">No matching problems</h3>
              <p className="state-description">
                Try adjusting your search or clearing one of the filters.
              </p>
              <button
                type="button"
                className="state-action-btn"
                onClick={handleClearFilters}
              >
                Clear filters
              </button>
            </div>
          </div>
        )}

        {/* STATE E: Real Populated Problems Grid (Full-Width Rectangular Cards) */}
        {!isLoading && !errorMessage && problems.length > 0 && (
          <>
            <div className="problems-grid" role="list">
              {problems.map((problem) => {
                const priorityKey = (problem.priority || 'LOW').toLowerCase();
                const priorityClass = `card-priority-${priorityKey}`;

                return (
                  <article
                    key={problem.id}
                    className={`problem-card problem-card-rectangular ${priorityClass}`}
                    tabIndex={0}
                    role="button"
                    onClick={() => handleCardClick(problem.id)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        handleCardClick(problem.id);
                      }
                    }}
                    aria-label={`Problem ${problem.title}, priority ${problem.priority}, category ${problem.category}`}
                  >
                    {/* Main Content Column */}
                    <div className="problem-card-main-col">
                      {/* Top Row: Priority Badge, Category Badge & Date */}
                      <div className="problem-card-top-row">
                        <div className="problem-badges-wrap">
                          {renderPriorityBadge(problem.priority)}
                          <span className="problem-category-badge">{problem.category}</span>
                        </div>
                        <div className="problem-card-time">
                          {new Date(problem.createdAt).toLocaleDateString(undefined, {
                            month: 'short',
                            day: 'numeric',
                            year: 'numeric',
                          })}
                        </div>
                      </div>

                      {/* Main Body: Title and Clean Clamped Description */}
                      <div className="problem-card-body">
                        <h3 className="problem-card-title" title={problem.title}>{problem.title}</h3>
                        {problem.description && (
                          <p className="problem-card-description" title={problem.description}>
                            {problem.description}
                          </p>
                        )}
                      </div>

                      {/* Metadata: Location & Linked Reports */}
                      <div className="problem-card-meta">
                        <div className="meta-row meta-location" title={`Location: ${problem.address || 'Unspecified'}`}>
                          <svg className="meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                            <circle cx="12" cy="10" r="3" />
                          </svg>
                          <span className="meta-text">{problem.address || 'Location Coordinates Recorded'}</span>
                        </div>

                        <span className="meta-divider" aria-hidden="true">•</span>

                        <div className="meta-row meta-reports">
                          <svg className="meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                          </svg>
                          <span>{problem.relatedReportCount} linked {problem.relatedReportCount === 1 ? 'report' : 'reports'}</span>
                        </div>
                      </div>
                    </div>

                    {/* Right Action Column: Status & View details button */}
                    <div className="problem-card-action-col">
                      {renderStatusIndicator(problem.status)}
                      <button
                        type="button"
                        className="view-details-btn"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleCardClick(problem.id);
                        }}
                        tabIndex={-1}
                        aria-hidden="true"
                      >
                        <span>View details</span>
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                          <line x1="5" y1="12" x2="19" y2="12" />
                          <polyline points="12 5 19 12 12 19" />
                        </svg>
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>

            {/* Pagination Controls */}
            {totalResults > 0 && (
              <nav className="problems-pagination" aria-label="Problems pagination">
                <div className="pagination-info">
                  Showing <strong>{(currentPage - 1) * pageSize + 1}</strong>–<strong>{Math.min(currentPage * pageSize, totalResults)}</strong> of <strong>{totalResults}</strong> problems
                </div>
                <div className="pagination-controls">
                  <button
                    type="button"
                    className="pagination-btn pagination-prev"
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    aria-label="Previous Page"
                  >
                    Previous
                  </button>

                  {Array.from({ length: Math.max(1, totalPages) }, (_, i) => i + 1).map((pageNum) => (
                    <button
                      key={pageNum}
                      type="button"
                      className={`pagination-btn ${pageNum === currentPage ? 'active' : ''}`}
                      onClick={() => setCurrentPage(pageNum)}
                      aria-current={pageNum === currentPage ? 'page' : undefined}
                    >
                      {pageNum}
                    </button>
                  ))}

                  <button
                    type="button"
                    className="pagination-btn pagination-next"
                    disabled={currentPage >= totalPages}
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    aria-label="Next Page"
                  >
                    Next
                  </button>
                </div>
              </nav>
            )}
          </>
        )}

      </div>

      {/* Navigation Notification Toast */}
      {activeToast && (
        <div className="problems-nav-toast" role="status">
          <span className="toast-tag">NAVIGATE</span>
          <span>{activeToast}</span>
        </div>
      )}

      {/* Problem Detail Modal */}
      {selectedProblemId && (
        <ProblemDetailModal
          token={token || localStorage.getItem('mehewara_token') || ''}
          problemId={selectedProblemId}
          onClose={() => setSelectedProblemId(null)}
        />
      )}
    </div>
  );
};
