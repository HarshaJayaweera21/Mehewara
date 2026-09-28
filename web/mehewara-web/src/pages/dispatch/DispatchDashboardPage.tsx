import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import type { User } from '../../types/auth';
import type {
  RecommendationListItem,
  RecommendationDetail,
  PriorityLevel,
} from '../../types/dispatch';
import type { CrewAvailabilityItem } from '../../types/crew';
import {
  getRecommendations,
  getRecommendationById,
} from '../../services/dispatchApi';
import { getCrewAvailability } from '../../services/crewApi';
import { Header } from '../../components/common';
import { ApproveRecommendationModal } from './components/ApproveRecommendationModal';
import { EditRecommendationModal } from './components/EditRecommendationModal';
import { RejectRecommendationModal } from './components/RejectRecommendationModal';
import { RegenerateRecommendationModal } from './components/RegenerateRecommendationModal';
import { ValidationReviewPanel } from './components/ValidationReviewPanel';
import './DispatchDashboardPage.css';
import './ReviewDashboard.css';

export interface DispatchDashboardPageProps {
  currentUser?: User | null;
  token?: string | null;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToCrews?: () => void;
  onNavigateToReports?: () => void;
  onOpenWorkOrder?: (id: string) => void;
}

const PRIORITIES: (PriorityLevel | 'ALL')[] = ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
const DECISIONS = ['ALL', 'PENDING', 'APPROVED', 'REJECTED'] as const;
const REVIEW_TABS = [ ['READY', 'Ready for Approval'], ['PROCESSING', 'Processing'],
  ['NEEDS_ATTENTION', 'Needs Attention'], ['DECIDED', 'Decided'], ['ALL', 'All / History'] ] as const;

export const DispatchDashboardPage: React.FC<DispatchDashboardPageProps> = ({
  currentUser,
  token,
  onLogout,
  onOpenProfile,
  onNavigateToProblems,
  onNavigateToCrews,
  onNavigateToReports,
  onOpenWorkOrder,
}) => {
  const authToken = token || localStorage.getItem('mehewara_token') || '';

  // Data states
  const [recommendations, setRecommendations] = useState<RecommendationListItem[]>([]);
  const [selectedRecId, setSelectedRecId] = useState<string | null>(null);
  const [selectedDetail, setSelectedDetail] = useState<RecommendationDetail | null>(null);
  const [availableCrews, setAvailableCrews] = useState<CrewAvailabilityItem[]>([]);
  const [isLoadingList, setIsLoadingList] = useState(true);
  const [isLoadingDetail, setIsLoadingDetail] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [activeToast, setActiveToast] = useState<{ message: string; type: 'success' | 'info' | 'error' } | null>(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [backendSearch, setBackendSearch] = useState('');
  const [selectedPriority, setSelectedPriority] = useState<string>('ALL');
  const [selectedDecision, setSelectedDecision] = useState<string>('ALL');
  const [reviewBucket, setReviewBucket] = useState('READY');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalItems, setTotalItems] = useState(0);
  const fetchSequence = useRef(0);
  const requestedSelection = useRef<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Modal states
  const [modalMode, setModalMode] = useState<'approve' | 'edit' | 'reject' | 'regenerate' | null>(null);

  const validationChecklist = (selectedDetail?.validation.checks ?? []).map((check) => ({
    id: check.code,
    label: check.code.replace(/_/g, ' '),
    passed: check.passed,
    note: check.message,
  }));

  // Auto-dismiss toast
  useEffect(() => {
    const timer = setTimeout(() => setBackendSearch(searchQuery.trim()), 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);
  useEffect(() => {
    if (activeToast) {
      const timer = setTimeout(() => setActiveToast(null), 4500);
      return () => clearTimeout(timer);
    }
  }, [activeToast]);

  // 1. Fetch recommendations and crew telemetry
  const fetchData = useCallback(async (quiet = false) => {
    if (!authToken) return;
    const sequence = ++fetchSequence.current;
    if (!quiet) setIsLoadingList(true);
    setErrorMessage(null);

    try {
      const [recsRes, crewsRes] = await Promise.all([
        getRecommendations(authToken, {
          priority: selectedPriority !== 'ALL' ? selectedPriority : undefined,
          page, pageSize: 20, reviewBucket, search: backendSearch || undefined,
          reviewDecision: selectedDecision !== 'ALL' ? selectedDecision : undefined,
        }),
        getCrewAvailability(authToken),
      ]);

      if (sequence !== fetchSequence.current) return;
      setTotalPages(Math.max(1, recsRes.totalPages)); setTotalItems(recsRes.totalItems);
      if (page > Math.max(1, recsRes.totalPages)) { setPage(Math.max(1, recsRes.totalPages)); return; }
      const items = recsRes.items || [];

      // Heuristic sort: Pending decisions first, then highest priority score
      const sorted = [...items].sort((a, b) => {
        if (!a.reviewDecision && b.reviewDecision) return -1;
        if (a.reviewDecision && !b.reviewDecision) return 1;
        return (b.priorityScore || 0) - (a.priorityScore || 0);
      });

      setRecommendations(sorted);
      setAvailableCrews(crewsRes.items || []);

      // Retain or auto-select first recommendation
      if (sorted.length > 0 || requestedSelection.current) {
        setSelectedRecId((prev) => requestedSelection.current || (prev && sorted.some((r) => r.recommendationId === prev) ? prev : sorted[0].recommendationId));
      } else {
        setSelectedRecId(null);
        setSelectedDetail(null);
      }
    } catch (err) {
      if (sequence === fetchSequence.current) setErrorMessage(err instanceof Error ? err.message : 'Unable to connect to dispatch recommendation engine.');
    } finally {
      if (sequence === fetchSequence.current) setIsLoadingList(false);
    }
  }, [authToken, selectedPriority, selectedDecision, backendSearch, reviewBucket, page]);

  useEffect(() => {
    fetchData();
    return () => { fetchSequence.current++; };
  }, [fetchData, refreshTrigger]);

  // 2. Fetch single detailed recommendation when selection changes
  useEffect(() => {
    if (!selectedRecId || !authToken) return;
    let ignore = false;
    setIsLoadingDetail(true);
    setSelectedDetail(null);

    getRecommendationById(authToken, selectedRecId)
      .then((detail) => {
        if (!ignore) {
          setSelectedDetail(detail);
          setIsLoadingDetail(false);
        }
      })
      .catch((err) => {
        if (!ignore) {
          console.error('Failed to load recommendation detail:', err);
          setErrorMessage(err instanceof Error ? err.message : 'Unable to load recommendation detail.');
          setIsLoadingDetail(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [selectedRecId, authToken, refreshTrigger]);

  // Refresh processing/attention views even when no row is selected. New children
  // and recommendations are discovered from the backend, not guessed from a parent job.
  useEffect(() => {
    if (!authToken || modalMode || isLoadingDetail) return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    async function poll() {
      await fetchData(true);
      if (cancelled) return;
      if (selectedRecId) {
        try {
          const fresh = await getRecommendationById(authToken, selectedRecId);
          if (!cancelled) setSelectedDetail(fresh);
        } catch { /* existing detail is retained; the next poll or manual refresh retries */ }
      }
      if (!cancelled) timer = setTimeout(poll, 5000);
    }
    timer = setTimeout(poll, 5000);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [authToken, modalMode, fetchData, selectedRecId, isLoadingDetail]);

  // Metrics summary
  const metrics = useMemo(() => {
    const total = recommendations.length;
    const pending = recommendations.filter((r) => !r.reviewDecision).length;
    const highCritical = recommendations.filter((r) => r.priority === 'CRITICAL' || r.priority === 'HIGH').length;
    const availableCrewCount = availableCrews.filter((c) => c.status === 'AVAILABLE').length;

    return { total, pending, highCritical, availableCrewCount };
  }, [recommendations, availableCrews]);

  // Active item in list (for modals)
  const activeListItem = useMemo(() => {
    return selectedDetail?.recommendationId === selectedRecId ? selectedDetail : recommendations.find((r) => r.recommendationId === selectedRecId) || null;
  }, [recommendations, selectedRecId, selectedDetail]);

  const handleActionSuccess = (msg: string) => {
    requestedSelection.current = null;
    setModalMode(null);
    setActiveToast({ message: msg, type: 'success' });
    setRefreshTrigger((prev) => prev + 1);
  };

  const getPriorityColorClass = (priority: string) => {
    switch (priority?.toUpperCase()) {
      case 'CRITICAL':
        return 'priority-critical';
      case 'HIGH':
        return 'priority-high';
      case 'MEDIUM':
        return 'priority-medium';
      default:
        return 'priority-low';
    }
  };

  const getStrategyBadge = (strategy?: string) => {
    switch (strategy?.toUpperCase()) {
      case 'IMMEDIATE_QUICK_WIN':
        return { label: '⚡ Quick Win', className: 'strategy-tag quick-win', tooltip: 'Low-effort defect (<60m) near crew location' };
      case 'URGENT_CRITICAL_PRIORITY':
        return { label: '🚨 Urgent Life Hazard', className: 'strategy-tag urgent-hazard', tooltip: 'Life-safety emergency override' };
      case 'CLUSTERED_EN_ROUTE':
        return { label: '📍 En Route Cluster', className: 'strategy-tag clustered', tooltip: 'Geographically clustered defect' };
      default:
        return null;
    }
  };

  return (
    <div className="dispatch-dashboard-container">
      {/* 1. Global Navigation Header */}
      <Header
        currentUser={currentUser}
        onLogout={onLogout}
        onOpenProfile={onOpenProfile}
        roleBadgeText="Municipal Coordinator"
      />

      <main className="dispatch-content-wrap">
        {/* Secondary Navigation Breadcrumbs / Module Switcher */}
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
              className="nav-strip-btn active"
              aria-current="page"
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
              className="nav-strip-btn"
              onClick={onNavigateToCrews}
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
            <button
              type="button"
              className="nav-strip-btn"
              onClick={() => onOpenWorkOrder?.('')}
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

        {/* 2. Operations Welcome Banner (Matches ProblemsPage Scenic Canvas) */}
        <section className="dispatch-welcome-banner" aria-label="Dispatch Operations Banner">
          <div className="dispatch-banner-content">
            <span className="banner-agent-badge">AI Agent 3 : Prioritization & Dispatch</span>
            <h1 className="dispatch-banner-heading">Municipal Dispatch Control Center</h1>
            <p className="dispatch-banner-sub">
              Human-in-the-loop authorization desk. Inspect multi-factor priority scores, examine real-time crew availability, and authorize municipal work orders.
            </p>
          </div>
        </section>

        {/* 3. Operational Metrics Strip */}
        <section className="dispatch-metrics-strip" aria-label="Key Dispatch Metrics">
          <div className="dispatch-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Pending Reviews</span>
              <span className="metric-mint-pip" title="Action Required" />
            </div>
            <div className="metric-value">{metrics.pending}</div>
            <div className="metric-descriptor">Awaiting coordinator authorization</div>
          </div>

          <div className="dispatch-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">High / Critical</span>
            </div>
            <div className="metric-value">{metrics.highCritical}</div>
            <div className="metric-descriptor">Priority score ≥ 60/100</div>
          </div>

          <div className="dispatch-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Total AI Assessed</span>
            </div>
            <div className="metric-value">{metrics.total}</div>
            <div className="metric-descriptor">Recommendations generated</div>
          </div>

          <div className="dispatch-metric-cell">
            <div className="metric-label-row">
              <span className="metric-label">Available Crews</span>
            </div>
            <div className="metric-value">{metrics.availableCrewCount} / 5</div>
            <div className="metric-descriptor">Standby for deployment</div>
          </div>
        </section>

        {/* 4. Filter Toolbar */}
        <nav className="dispatch-review-tabs" aria-label="Recommendation review views">
          {REVIEW_TABS.map(([value, label]) => <button key={value} type="button"
            aria-pressed={reviewBucket === value} className={reviewBucket === value ? 'active' : ''}
            onClick={() => { requestedSelection.current = null; setReviewBucket(value); setSelectedDecision('ALL'); setPage(1); setModalMode(null); }}>{label}</button>)}
        </nav>
        <div className="dispatch-pagination" aria-live="polite">
          <span>{totalItems} matching recommendations · Page {page} of {totalPages}. Recommendation summaries describe this page; crew availability describes the roster.</span>
          <button type="button" disabled={page <= 1 || isLoadingList} onClick={() => { requestedSelection.current = null; setPage(p => p - 1); }}>Previous</button>
          <button type="button" disabled={page >= totalPages || isLoadingList} onClick={() => { requestedSelection.current = null; setPage(p => p + 1); }}>Next</button>
        </div>
        <section className="dispatch-toolbar" aria-label="Filter Dispatch Recommendations">
          <div className="dispatch-search-box">
            <svg className="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              className="dispatch-search-input"
              placeholder="Search problem title, category, crew or Problem ID..."
              value={searchQuery}
              onChange={(e) => { requestedSelection.current = null; setSearchQuery(e.target.value); setPage(1); }}
              aria-label="Search dispatch recommendations"
            />
          </div>

          <div className="dispatch-filters-group">
            {/* Priority Filter */}
            <div className="dispatch-filter-wrap">
              <select
                className="dispatch-filter-select"
                value={selectedPriority}
                onChange={(e) => { requestedSelection.current = null; setSelectedPriority(e.target.value); setPage(1); }}
                aria-label="Filter by Priority"
              >
                {PRIORITIES.map((pri) => (
                  <option key={pri} value={pri}>
                    {pri === 'ALL' ? 'Priority: All' : pri}
                  </option>
                ))}
              </select>
            </div>

            {/* Decision Filter */}
            <div className="dispatch-filter-wrap">
              <select
                className="dispatch-filter-select"
                value={selectedDecision}
                onChange={(e) => { requestedSelection.current = null; setSelectedDecision(e.target.value); setPage(1); }}
                aria-label="Filter by Decision"
              >
                {DECISIONS.map((dec) => (
                  <option key={dec} value={dec}>
                    {dec === 'ALL' ? 'Review: All' : dec}
                  </option>
                ))}
              </select>
            </div>

            {(searchQuery.trim() !== '' || selectedPriority !== 'ALL' || selectedDecision !== 'ALL') && (
              <button
                type="button"
                className="dispatch-clear-filters-btn"
                onClick={() => {
                  setSearchQuery('');
                  requestedSelection.current = null;
                  setSelectedPriority('ALL');
                  setSelectedDecision('ALL');
                  setPage(1);
                }}
              >
                Clear filters
              </button>
            )}

            <button
              type="button"
              className="dispatch-refresh-btn"
              onClick={() => setRefreshTrigger((prev) => prev + 1)}
              title="Refresh queue"
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

        {/* Toast Alert */}
        {activeToast && (
          <div className={`dispatch-toast toast-${activeToast.type}`}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
              <polyline points="22 4 12 14.01 9 11.01" />
            </svg>
            <span>{activeToast.message}</span>
          </div>
        )}

        {errorMessage && (
          <div className="dispatch-error-banner">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <span>{errorMessage}</span>
          </div>
        )}

        {/* 5. Master-Detail Split Layout */}
        <div className="dispatch-split-layout">
          {/* Left Panel: Queue List */}
          <section className="dispatch-queue-panel" aria-label="Recommendation Queue">
            <div className="queue-panel-header">
              <h2 className="queue-panel-title">
                Priority Queue
                <span className="queue-count-pill">{recommendations.length}</span>
              </h2>
              <span className="queue-sort-label">Sorted by Priority & Urgency</span>
            </div>

            {isLoadingList && (
              <div className="queue-skeleton-list">
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} className="queue-item-card skeleton-card">
                    <div className="skeleton-box" style={{ width: '40%', height: '14px', marginBottom: '8px' }} />
                    <div className="skeleton-box" style={{ width: '85%', height: '18px', marginBottom: '8px' }} />
                    <div className="skeleton-box" style={{ width: '60%', height: '12px' }} />
                  </div>
                ))}
              </div>
            )}

            {!isLoadingList && recommendations.length === 0 && (
              <div className="queue-empty-state">
                <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#8F9995" strokeWidth="1.5">
                  <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                  <polyline points="22 4 12 14.01 9 11.01" />
                </svg>
                <h3>All Clear</h3>
                <p>No dispatch recommendations matching the current filter criteria.</p>
              </div>
            )}

            {!isLoadingList && recommendations.length > 0 && (
              <div className="queue-items-container">
                {recommendations.map((rec) => {
                  const isSelected = rec.recommendationId === selectedRecId;
                  const isApproved = rec.reviewDecision === 'APPROVED';
                  const isRejected = rec.reviewDecision === 'REJECTED';

                  return (
                    <article
                      key={rec.recommendationId}
                      className={`queue-item-card ${isSelected ? 'selected' : ''}`}
                      onClick={() => { requestedSelection.current = null; setSelectedRecId(rec.recommendationId); }}
                      tabIndex={0}
                      role="button"
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          requestedSelection.current = null; setSelectedRecId(rec.recommendationId);
                        }
                      }}
                    >
                      <div className="queue-item-top">
                        <span className="queue-category-badge">{rec.category}</span>
                        <div className="queue-badges-row">
                          {(() => {
                            const strat = getStrategyBadge(rec.dispatchStrategy);
                            return strat ? (
                              <span className={strat.className} title={strat.tooltip}>
                                {strat.label}
                              </span>
                            ) : null;
                          })()}
                          <span className={`priority-tag ${getPriorityColorClass(rec.priority)}`}>
                            {rec.priority} ({rec.priorityScore})
                          </span>
                          {isApproved && <span className="decision-tag approved">APPROVED</span>}
                          {isRejected && <span className="decision-tag rejected">REJECTED</span>}
                          {!rec.reviewDecision && <span className="decision-tag pending">{rec.reviewProgress.replace(/_/g, ' ')}</span>}
                          {rec.origin === 'HUMAN_OVERRIDE' && <span className="decision-tag pending">Human override</span>}
                        </div>
                      </div>

                      <h3 className="queue-item-title">{rec.problemTitle}</h3>

                      {(rec.estimatedDurationMinutes || rec.distanceKm != null) && (
                        <div className="queue-item-telemetry-row">
                          {rec.estimatedDurationMinutes && (
                            <span className="queue-telemetry-pill duration-pill" title="Estimated remediation duration">
                              ⏱️ ~{rec.estimatedDurationMinutes}m fix
                            </span>
                          )}
                          {rec.distanceKm != null && (
                            <span className="queue-telemetry-pill distance-pill" title="Crew proximity distance">
                              📍 {rec.distanceKm.toFixed(1)} km
                            </span>
                          )}
                          {rec.estimatedTravelMinutes != null && (
                            <span className="queue-telemetry-pill transit-pill" title="Estimated driving transit">
                              🚗 ~{rec.estimatedTravelMinutes}m drive
                            </span>
                          )}
                        </div>
                      )}

                      <div className="queue-item-footer">
                        <div className="queue-crew-info">
                          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                            <circle cx="9" cy="7" r="4" />
                          </svg>
                          <span className="queue-crew-name">
                            {rec.recommendedCrewName || 'No Crew Available'}
                          </span>
                        </div>
                        <span className="queue-time-ago">
                          {new Date(rec.createdAt).toLocaleDateString(undefined, {
                            month: 'short',
                            day: 'numeric',
                          })}
                        </span>
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </section>

          {/* Right Panel: Active Recommendation Detail */}
          <section className="dispatch-detail-panel" aria-label="Recommendation Detail">
            {isLoadingDetail && (
              <div className="detail-loading-state">
                <div className="dispatch-spinner-pip" />
                <span>Loading recommendation telemetry...</span>
              </div>
            )}

            {!isLoadingDetail && !selectedDetail && (
              <div className="detail-empty-state">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#8F9995" strokeWidth="1.2">
                  <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                  <line x1="8" y1="21" x2="16" y2="21" />
                  <line x1="12" y1="17" x2="12" y2="21" />
                </svg>
                <h3>Select a Recommendation</h3>
                <p>Choose an item from the priority queue on the left to inspect its multi-factor score and authorize dispatch.</p>
              </div>
            )}

            {!isLoadingDetail && selectedDetail && (
              <div className="detail-content-card">
                {/* Detail Header & Action Buttons */}
                <div className="detail-header-row">
                  <div>
                    <div className="detail-meta-tags">
                      <span className="detail-category-tag">{selectedDetail.category}</span>
                      <span className="detail-ref-tag">Problem ID: {selectedDetail.problemId.substring(0, 8)}...</span>
                      {(() => {
                        const strat = getStrategyBadge(selectedDetail.dispatchStrategy);
                        return strat ? (
                          <span className={strat.className} title={strat.tooltip}>
                            {strat.label}
                          </span>
                        ) : null;
                      })()}
                      {selectedDetail.reviewDecision === 'APPROVED' && (
                        <span className="detail-status-pill approved">
                          <span className="status-dot green" /> Work Order Authorized
                        </span>
                      )}
                      {selectedDetail.reviewDecision === 'REJECTED' && (
                        <span className="detail-status-pill rejected">
                          <span className="status-dot red" /> Recommendation Rejected
                        </span>
                      )}
                    </div>
                    <h2 className="detail-problem-title">{selectedDetail.problemTitle}</h2>
                    {selectedDetail.address && (
                      <p className="detail-address-text">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                          <circle cx="12" cy="10" r="3" />
                        </svg>
                        <span>{selectedDetail.address}</span>
                      </p>
                    )}
                  </div>

                  {/* Actions Header Strip */}
                  <div className="detail-action-buttons">
                    <button
                      type="button"
                      className="dispatch-action-btn edit-btn"
                      onClick={() => setModalMode('edit')}
                      title={selectedDetail.reviewDecision ? 'Cannot override a reviewed recommendation' : 'Override priority, score or assigned crew'}
                      disabled={!selectedDetail.allowedActions.includes('EDIT')}
                    >
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M12 20h9" />
                        <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
                      </svg>
                      <span>Edit</span>
                    </button>

                    <button
                      type="button"
                      className="dispatch-action-btn regen-btn"
                      onClick={() => setModalMode('regenerate')}
                      disabled={!selectedDetail.allowedActions.includes('REGENERATE')}
                      title="Generate a new recommendation and validate it"
                    >
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <polyline points="23 4 23 10 17 10" />
                        <polyline points="1 20 1 14 7 14" />
                        <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
                      </svg>
                      <span>Regenerate</span>
                    </button>

                    <button
                      type="button"
                      className="dispatch-action-btn reject-btn"
                      onClick={() => setModalMode('reject')}
                      title="Reject recommendation"
                      disabled={!selectedDetail.allowedActions.includes('REJECT')}
                    >
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <line x1="18" y1="6" x2="6" y2="18" />
                        <line x1="6" y1="6" x2="18" y2="18" />
                      </svg>
                      <span>Reject</span>
                    </button>

                    <button
                      type="button"
                      className="dispatch-action-btn approve-btn"
                      onClick={() => setModalMode('approve')}
                      title="Approve and create Municipal Work Order"
                      disabled={!selectedDetail.allowedActions.includes('APPROVE')}
                    >
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                      <span>{selectedDetail.reviewDecision === 'APPROVED' ? 'Approved' : 'Approve & Dispatch'}</span>
                    </button>
                  </div>
                </div>

                {/* Rejection / Approval Banner if already reviewed */}
                {selectedDetail.reviewReason && (
                  <div className={`detail-review-notice ${selectedDetail.reviewDecision === 'APPROVED' ? 'approved' : 'rejected'}`}>
                    <span className="notice-title">
                      {selectedDetail.reviewDecision === 'APPROVED' ? 'Coordinator Authorization Notes' : 'Rejection Reason'}:
                    </span>
                    <p className="notice-body">{selectedDetail.reviewReason}</p>
                    {selectedDetail.reviewedBy && (
                      <span className="notice-by">Reviewed by {selectedDetail.reviewedBy} on {selectedDetail.reviewedAt ? new Date(selectedDetail.reviewedAt).toLocaleDateString() : ''}</span>
                    )}
                  </div>
                )}

                {/* Priority Score Bar / Gauge */}
                <div className="detail-section score-section">
                  <div className="score-header">
                    <div>
                      <span className="detail-section-label">AI Assessed Priority</span>
                      <div className="score-badge-val">
                        <span className={`priority-tag-large ${getPriorityColorClass(selectedDetail.priority)}`}>
                          {selectedDetail.priority}
                        </span>
                        <span className="score-number-display">{selectedDetail.priorityScore} / 100</span>
                      </div>
                    </div>
                    <span className="score-formula-hint">Multi-factor: Severity (30%) + Risk (25%) + Reports (20%) + Location (15%) + Age (10%)</span>
                  </div>

                  <div className="score-bar-track">
                    <div
                      className={`score-bar-fill fill-${selectedDetail.priority.toLowerCase()}`}
                      style={{ width: `${Math.min(100, Math.max(5, selectedDetail.priorityScore))}%` }}
                    />
                  </div>
                </div>

                {/* AI Reasoning & Justifications */}
                <div className="detail-section reasoning-section">
                  <span className="detail-section-label">Agent 3 Priority Rationale</span>
                  {selectedDetail.priorityReasons && selectedDetail.priorityReasons.length > 0 ? (
                    <ul className="reasons-list">
                      {selectedDetail.priorityReasons.map((reason, idx) => (
                        <li key={idx} className="reason-item">
                          <span className="reason-bullet" />
                          <span>{reason}</span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="reason-text">{selectedDetail.recommendationReason || 'Standard municipal defect prioritization.'}</p>
                  )}
                </div>

                {/* Recommended Municipal Crew Box */}
                <div className="detail-section crew-section">
                  <div className="crew-section-header">
                    <span className="detail-section-label">Recommended Municipal Crew</span>
                    <button
                      type="button"
                      className="crew-change-btn"
                      onClick={() => setModalMode('edit')}
                    >
                      Change Crew
                    </button>
                  </div>

                  <div className="crew-profile-card">
                    <div className="crew-profile-left">
                      <div className="crew-avatar-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                          <circle cx="9" cy="7" r="4" />
                        </svg>
                      </div>
                      <div>
                        <h4 className="crew-name">{selectedDetail.recommendedCrewName || 'Unassigned / Needs Manual Selection'}</h4>
                        <span className="crew-specialization">{selectedDetail.requiredCrewType} Specialization</span>
                      </div>
                    </div>

                    <div className="crew-profile-right">
                      <div className={`crew-status-indicator ${selectedDetail.recommendedCrewStatus === 'AVAILABLE' ? 'available' : 'busy'}`}>
                        <span className="status-dot" />
                        <span>{selectedDetail.recommendedCrewStatus || 'UNKNOWN'}</span>
                      </div>
                      <span className="crew-ward-hint">Crew status</span>
                    </div>
                  </div>
                </div>

                <ValidationReviewPanel key={selectedDetail.recommendationId} detail={selectedDetail} token={authToken}
                  onChange={(id, bucket) => { if (id) { requestedSelection.current = id; setReviewBucket('ALL'); setPage(1); setSelectedRecId(id); }
                    if (bucket) { requestedSelection.current = null; setReviewBucket(bucket); setPage(1); } setRefreshTrigger(v => v + 1); }} />
                {selectedDetail.workOrderId && <button className="dispatch-btn-primary" onClick={() => onOpenWorkOrder?.(selectedDetail.workOrderId!)}>View WorkOrder</button>}
                {/* Opportunistic Routing & Execution Telemetry */}
                <div className="detail-section telemetry-section">
                  <div className="telemetry-header">
                    <div>
                      <span className="detail-section-label">Opportunistic Routing & Execution Telemetry</span>
                      <p className="telemetry-sub">Recommendation travel and repair estimates. Crew availability is checked again at approval.</p>
                    </div>
                    {selectedDetail.dispatchStrategy === 'IMMEDIATE_QUICK_WIN' && (
                      <span className="telemetry-opportunity-tag">
                        ⚡ High Efficiency Quick Win
                      </span>
                    )}
                  </div>

                  <div className="telemetry-grid">
                    <div className="telemetry-cell">
                      <span className="telemetry-cell-label">Est. Remediation Duration</span>
                      <div className="telemetry-cell-value">
                        {selectedDetail.estimatedDurationMinutes ? `${selectedDetail.estimatedDurationMinutes} mins` : 'Standard (~60m)'}
                      </div>
                      <span className="telemetry-cell-desc">Duration to repair on-site</span>
                    </div>

                    <div className="telemetry-cell">
                      <span className="telemetry-cell-label">Crew Distance</span>
                      <div className="telemetry-cell-value">
                        {selectedDetail.distanceKm != null ? `${selectedDetail.distanceKm.toFixed(1)} km` : 'Depot / Standby'}
                      </div>
                      <span className="telemetry-cell-desc">Haversine with urban tortuosity</span>
                    </div>

                    <div className="telemetry-cell">
                      <span className="telemetry-cell-label">Est. Transit Time</span>
                      <div className="telemetry-cell-value">
                        {selectedDetail.estimatedTravelMinutes != null ? `${selectedDetail.estimatedTravelMinutes} mins` : '~15 mins'}
                      </div>
                      <span className="telemetry-cell-desc">At average urban speeds</span>
                    </div>

                    <div className="telemetry-cell">
                      <span className="telemetry-cell-label">Dispatch Strategy</span>
                      <div className="telemetry-cell-value strategy-name">
                        {selectedDetail.dispatchStrategy?.replace(/_/g, ' ') || 'STANDARD DISPATCH'}
                      </div>
                      <span className="telemetry-cell-desc">
                        {selectedDetail.dispatchStrategy === 'IMMEDIATE_QUICK_WIN'
                          ? 'Prioritized before distant jobs'
                          : selectedDetail.dispatchStrategy === 'URGENT_CRITICAL_PRIORITY'
                          ? 'Life safety override takes precedence'
                          : 'Normal sequence'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Recorded Agent 4 checks; no frontend assumptions are treated as passing validation. */}
                <div className="detail-section checklist-section">
                  <div className="checklist-header">
                    <div>
                      <span className="detail-section-label">Recorded Agent 4 Checks</span>
                      <p className="checklist-sub">Checks from the saved review. Approval requires a passing review for the current revision.</p>
                    </div>
                    <span className="checklist-count-badge">
                      {validationChecklist.filter((c) => c.passed).length} / {validationChecklist.length} Passed
                    </span>
                  </div>

                  {validationChecklist.length === 0 && <p>No Agent 4 checks have been recorded for this review.</p>}
                  <div className="checklist-grid">
                    {validationChecklist.map((item) => (
                      <div
                        key={item.id}
                        className={`checklist-item ${item.passed ? 'passed' : 'pending'}`}
                      >
                        <div className="item-icon">
                          {item.passed ? (
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                              <polyline points="20 6 9 17 4 12" />
                            </svg>
                          ) : (
                            <span className="pending-dot" />
                          )}
                        </div>
                        <div className="item-text-group">
                          <span className="item-label">{item.label}</span>
                          <span className="item-note">{item.note}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </section>
        </div>
      </main>

      {/* Decision Modals */}
      {modalMode === 'approve' && activeListItem && (
        <ApproveRecommendationModal
          recommendation={selectedDetail || activeListItem}
          token={authToken}
          onClose={() => setModalMode(null)}
          onSuccess={(workOrderId) => {
            setReviewBucket('DECIDED'); setPage(1);
            handleActionSuccess(`Work Order ${workOrderId.substring(0, 8)} authorized successfully.`);
            onOpenWorkOrder?.(workOrderId);
          }}
        />
      )}

      {modalMode === 'edit' && activeListItem && (
        <EditRecommendationModal
          recommendation={selectedDetail || activeListItem}
          token={authToken}
          onClose={() => setModalMode(null)}
          onSuccess={(updatedDetail) => {
            // Immediately update the right panel with fresh data from the server
            setSelectedDetail(updatedDetail);
            setReviewBucket(updatedDetail.reviewBucket === 'HISTORY' ? 'ALL' : updatedDetail.reviewBucket); setPage(1);
            handleActionSuccess(updatedDetail.requiresResponsibilityAcknowledgement
              ? 'Human override saved. Review backend eligibility and acknowledge responsibility before approval.'
              : 'Recommendation saved. Review the current validation and available actions.');
          }}
        />
      )}

      {modalMode === 'regenerate' && activeListItem && (
        <RegenerateRecommendationModal recommendation={selectedDetail || activeListItem} token={authToken}
          onClose={() => setModalMode(null)} onSuccess={() => { setReviewBucket('PROCESSING'); setPage(1); handleActionSuccess('Regeneration queued. Progress appears in the review panel.'); }} />
      )}

      {modalMode === 'reject' && activeListItem && (
        <RejectRecommendationModal
          recommendation={selectedDetail || activeListItem}
          token={authToken}
          onClose={() => setModalMode(null)}
          onSuccess={() => { setReviewBucket('DECIDED'); setPage(1); handleActionSuccess('Recommendation rejected.'); }}
        />
      )}


    </div>
  );
};
