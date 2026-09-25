import React, { useState, useEffect } from 'react';
import type { ProblemDetailResponse, RelatedReportSummary } from '../../types/problems';
import type { ReportResponse } from '../../types/reports';
import { getProblemById } from '../../services/problemApi';
import { getReportById } from '../../services/reportApi';
import { ReportLocationMap } from '../../components/common/ReportLocationMap';
import './ProblemDetailModal.css';

// ─── Constants ────────────────────────────────────────────────────────────────

const CATEGORY_DISPLAY: Record<string, string> = {
  ROAD: 'Road',
  DRAINAGE: 'Drainage',
  WASTE: 'Waste',
  ELECTRICAL: 'Electrical',
  ENVIRONMENT: 'Environment',
};

// ─── Helper Functions ─────────────────────────────────────────────────────────

function formatDate(dateStr: string): string {
  try {
    return new Date(dateStr).toLocaleString('en-US', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });
  } catch {
    return dateStr;
  }
}

function getPriorityClass(priority: string | null): string {
  const p = (priority || 'LOW').toUpperCase();
  if (p === 'CRITICAL') return 'pdm-priority-critical';
  if (p === 'HIGH') return 'pdm-priority-high';
  if (p === 'MEDIUM') return 'pdm-priority-medium';
  return 'pdm-priority-low';
}

function getStatusClass(status: string): string {
  const s = status.toUpperCase();
  if (s === 'IN_PROGRESS') return 'pdm-status-in_progress';
  if (s === 'ASSIGNED') return 'pdm-status-assigned';
  if (s === 'RESOLVED') return 'pdm-status-resolved';
  if (s === 'AWAITING_ASSIGNMENT') return 'pdm-status-awaiting_assignment';
  return 'pdm-status-identified';
}

function getStatusLabel(status: string): string {
  const s = status.toUpperCase();
  if (s === 'IN_PROGRESS') return 'IN PROGRESS';
  if (s === 'AWAITING_ASSIGNMENT') return 'AWAITING ASSIGNMENT';
  return s;
}

function getReportStatusClass(status: string): string {
  const s = status.toUpperCase();
  if (s === 'PENDING') return 'pdm-report-status-pending';
  if (s === 'PROCESSING') return 'pdm-report-status-processing';
  if (s === 'ASSIGNED') return 'pdm-report-status-assigned';
  if (s === 'RESOLVED') return 'pdm-report-status-resolved';
  if (s === 'CANCELLED') return 'pdm-report-status-cancelled';
  return 'pdm-report-status-pending';
}

// ─── Sub-component: Individual Report Detail Popup ────────────────────────────

interface ReportDetailPopupProps {
  token: string;
  reportId: string;
  onClose: () => void;
  zLevel?: 'l2' | 'l3';
}

const ReportDetailPopup: React.FC<ReportDetailPopupProps> = ({
  token,
  reportId,
  onClose,
  zLevel = 'l2',
}) => {
  const [report, setReport] = useState<ReportResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;
    setLoading(true);
    setError(null);

    getReportById(token, reportId)
      .then((data) => {
        if (!ignore) setReport(data);
      })
      .catch((err: unknown) => {
        if (!ignore) setError(err instanceof Error ? err.message : 'Failed to load report.');
      })
      .finally(() => {
        if (!ignore) setLoading(false);
      });

    return () => { ignore = true; };
  }, [token, reportId]);

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [onClose]);

  return (
    <div
      className={`pdm-stacked-overlay ${zLevel === 'l3' ? 'pdm-stacked-overlay-l3' : ''}`}
      onClick={onClose}
    >
      <div className="pdm-stacked-modal" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="pdm-rd-header">
          <div className="pdm-rd-header-left">
            <h3 className="pdm-rd-title">Report Details</h3>
            <div className="pdm-id-badge">
              <span>Report ID: {reportId}</span>
            </div>
          </div>
          <button type="button" className="pdm-close-btn" onClick={onClose} aria-label="Close">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        {/* Body */}
        <div className="pdm-rd-body">
          {loading && (
            <div className="pdm-loading">
              <div className="pdm-spinner" />
              <span>Loading report details…</span>
            </div>
          )}

          {error && (
            <div className="pdm-error">
              <div className="pdm-error-icon">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
              </div>
              <p className="pdm-error-text">{error}</p>
            </div>
          )}

          {report && !loading && (
            <>
              {/* Info Grid: ID, Category, Status, Date */}
              <div className="pdm-rd-section">
                <div className="pdm-rd-info-grid">
                  <div className="pdm-rd-info-item">
                    <span className="pdm-rd-info-label">Report ID</span>
                    <span className="pdm-rd-info-value" style={{ fontFamily: "'SF Mono', 'Fira Code', monospace", fontSize: '0.75rem' }}>
                      Report ID: {report.id}
                    </span>
                  </div>
                  <div className="pdm-rd-info-item">
                    <span className="pdm-rd-info-label">Category</span>
                    <span className="pdm-rd-info-value">
                      {CATEGORY_DISPLAY[report.category] || report.category}
                    </span>
                  </div>
                  <div className="pdm-rd-info-item">
                    <span className="pdm-rd-info-label">Status</span>
                    <span className={`pdm-report-status-mini ${getReportStatusClass(report.status)}`}>
                      {report.status}
                    </span>
                  </div>
                  <div className="pdm-rd-info-item">
                    <span className="pdm-rd-info-label">Submitted</span>
                    <span className="pdm-rd-info-value">{formatDate(report.createdAt)}</span>
                  </div>
                </div>
              </div>

              {/* Resident */}
              <div className="pdm-rd-section">
                <div className="pdm-rd-section-label">Submitted By</div>
                <div className="pdm-rd-resident-card">
                  <div className="pdm-rd-resident-avatar">
                    {report.residentName ? report.residentName.charAt(0).toUpperCase() : 'R'}
                  </div>
                  <div>
                    <div className="pdm-rd-resident-name">{report.residentName || 'Resident'}</div>
                    <div className="pdm-rd-resident-id">{report.residentEmail || `ID: ${report.residentId}`}</div>
                  </div>
                </div>
              </div>

              {/* Description */}
              <div className="pdm-rd-section">
                <div className="pdm-rd-section-label">Description</div>
                <p className="pdm-rd-desc-text">{report.description}</p>
              </div>

              {/* Location & Map */}
              <div className="pdm-rd-section">
                <div className="pdm-rd-section-label">Location</div>
                {report.address && (
                  <div className="pdm-address-row" style={{ marginBottom: '0.65rem' }}>
                    <svg className="pdm-address-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                      <circle cx="12" cy="10" r="3" />
                    </svg>
                    <span className="pdm-address-text">{report.address}</span>
                  </div>
                )}
                <div className="pdm-map-container">
                  <ReportLocationMap
                    latitude={report.latitude}
                    longitude={report.longitude}
                    label={`${report.category} Report`}
                    height="180px"
                  />
                </div>
              </div>

              {/* Photos */}
              <div className="pdm-rd-section">
                <div className="pdm-rd-section-label">Photos ({report.photos.length})</div>
                {report.photos.length > 0 ? (
                  <div className="pdm-rd-photos-grid">
                    {report.photos.map((photo) => (
                      <a
                        key={photo.photoId}
                        href={photo.photoUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="pdm-rd-photo-card"
                        title={photo.fileName || 'View full size'}
                      >
                        <img src={photo.photoUrl} alt={photo.fileName || 'Report photo'} className="pdm-rd-photo-img" />
                      </a>
                    ))}
                  </div>
                ) : (
                  <div className="pdm-rd-no-photos">No photos attached to this report.</div>
                )}
              </div>
            </>
          )}
        </div>

      </div>
    </div>
  );
};

// ─── Sub-component: All Reports List Popup ────────────────────────────────────

interface AllReportsPopupProps {
  token: string;
  reports: RelatedReportSummary[];
  onClose: () => void;
}

const AllReportsPopup: React.FC<AllReportsPopupProps> = ({ token, reports, onClose }) => {
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null);

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (selectedReportId) {
          setSelectedReportId(null);
        } else {
          onClose();
        }
      }
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [onClose, selectedReportId]);

  return (
    <>
      <div className="pdm-stacked-overlay" onClick={onClose}>
        <div className="pdm-stacked-modal" onClick={(e) => e.stopPropagation()}>
          {/* Header */}
          <div className="pdm-rd-header">
            <div className="pdm-all-reports-title-row">
              <h3 className="pdm-rd-title">All Linked Reports</h3>
              <span className="pdm-all-reports-count">{reports.length}</span>
            </div>
            <button type="button" className="pdm-close-btn" onClick={onClose} aria-label="Close">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          {/* Body: Report Rows */}
          <div className="pdm-rd-body">
            <div className="pdm-section" style={{ padding: '1rem 1.5rem' }}>
              {reports.map((r) => (
                <div
                  key={r.reportId}
                  className="pdm-report-row"
                  onClick={() => setSelectedReportId(r.reportId)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      setSelectedReportId(r.reportId);
                    }
                  }}
                >
                  <div className="pdm-report-row-left">
                    <span className="pdm-report-id-label">
                      <span className="pdm-report-id-prefix">Report ID:</span>
                      {r.reportId}
                    </span>
                  </div>
                  <svg className="pdm-report-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </div>
              ))}
            </div>
          </div>

        </div>
      </div>

      {/* Level 3: Individual Report Detail from All Reports list */}
      {selectedReportId && (
        <ReportDetailPopup
          token={token}
          reportId={selectedReportId}
          onClose={() => setSelectedReportId(null)}
          zLevel="l3"
        />
      )}
    </>
  );
};


// ─── Main Component: Problem Detail Modal ─────────────────────────────────────

export interface ProblemDetailModalProps {
  token: string;
  problemId: string;
  onClose: () => void;
}

export const ProblemDetailModal: React.FC<ProblemDetailModalProps> = ({
  token,
  problemId,
  onClose,
}) => {
  const [problem, setProblem] = useState<ProblemDetailResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);

  // Stacked modal states
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null);
  const [showAllReports, setShowAllReports] = useState(false);

  const VISIBLE_REPORTS_LIMIT = 3;

  // Fetch problem details
  useEffect(() => {
    let ignore = false;
    setIsLoading(true);
    setError(null);

    const authToken = token || localStorage.getItem('mehewara_token') || '';

    getProblemById(authToken, problemId)
      .then((data) => {
        if (!ignore) {
          setProblem(data);
          setIsLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!ignore) {
          setError(err instanceof Error ? err.message : 'Failed to load problem details.');
          setIsLoading(false);
        }
      });

    return () => { ignore = true; };
  }, [token, problemId, retryCount]);

  // Close on Escape (only if no stacked modal is open)
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !selectedReportId && !showAllReports) {
        onClose();
      }
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [onClose, selectedReportId, showAllReports]);

  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => { document.body.style.overflow = ''; };
  }, []);


  const visibleReports = problem?.relatedReports?.slice(0, VISIBLE_REPORTS_LIMIT) || [];
  const totalReports = problem?.relatedReports?.length || 0;
  const remainingReports = totalReports - VISIBLE_REPORTS_LIMIT;

  return (
    <>
      {/* Level 1: Main Problem Detail Modal */}
      <div className="pdm-overlay" onClick={onClose}>
        <div className="pdm-modal" onClick={(e) => e.stopPropagation()}>
          {/* Header: Title + Close */}
          <div className="pdm-header">
            <div className="pdm-header-left">
              <h2 className="pdm-title">
                {isLoading ? 'Loading Problem…' : problem?.title || 'Problem Details'}
              </h2>
              {!isLoading && problem && (
                <div className="pdm-id-badge">
                  <span>ID: {problemId}</span>
                </div>
              )}
            </div>
            <button type="button" className="pdm-close-btn" onClick={onClose} aria-label="Close modal">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          {/* Body */}
          <div className="pdm-body">
            {/* Loading State */}
            {isLoading && (
              <div className="pdm-loading">
                <div className="pdm-spinner" />
                <span>Fetching problem details…</span>
              </div>
            )}

            {/* Error State */}
            {!isLoading && error && (
              <div className="pdm-error">
                <div className="pdm-error-icon">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="12" />
                    <line x1="12" y1="16" x2="12.01" y2="16" />
                  </svg>
                </div>
                <p className="pdm-error-text">{error}</p>
                <button type="button" className="pdm-retry-btn" onClick={() => setRetryCount((c) => c + 1)}>
                  Try again
                </button>
              </div>
            )}

            {/* Loaded Content */}
            {!isLoading && problem && (
              <>
                {/* Status Bar: Priority + Status + Category */}
                <div className="pdm-status-bar">
                  <span className={`pdm-priority-badge ${getPriorityClass(problem.priority)}`}>
                    {(problem.priority || 'LOW').toUpperCase()}
                  </span>
                  <span className={`pdm-status-pill ${getStatusClass(problem.status)}`}>
                    <span className="pdm-status-dot" aria-hidden="true" />
                    <span>{getStatusLabel(problem.status)}</span>
                  </span>
                  <span className="pdm-category-tag">
                    {CATEGORY_DISPLAY[problem.category] || problem.category}
                  </span>
                </div>

                {/* Description */}
                {problem.description && (
                  <div className="pdm-section">
                    <div className="pdm-section-label">Description</div>
                    <p className="pdm-description-text">{problem.description}</p>
                  </div>
                )}

                {/* Timeline: Created & Updated */}
                <div className="pdm-section">
                  <div className="pdm-section-label">Timeline</div>
                  <div className="pdm-timeline-grid">
                    <div className="pdm-timeline-item">
                      <span className="pdm-timeline-label">Created</span>
                      <span className="pdm-timeline-value">{formatDate(problem.createdAt)}</span>
                    </div>
                    <div className="pdm-timeline-item">
                      <span className="pdm-timeline-label">Last Updated</span>
                      <span className="pdm-timeline-value">{formatDate(problem.updatedAt)}</span>
                    </div>
                  </div>
                </div>

                {/* Location & Map */}
                <div className="pdm-section">
                  <div className="pdm-section-label">Location</div>
                  {problem.address && (
                    <div className="pdm-address-row">
                      <svg className="pdm-address-icon" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                        <circle cx="12" cy="10" r="3" />
                      </svg>
                      <span className="pdm-address-text">{problem.address}</span>
                    </div>
                  )}
                  <div className="pdm-map-container">
                    <ReportLocationMap
                      latitude={problem.latitude}
                      longitude={problem.longitude}
                      label={problem.title}
                      height="200px"
                    />
                  </div>
                </div>

                {/* Linked Reports */}
                <div className="pdm-section">
                  <div className="pdm-reports-header">
                    <div className="pdm-section-label" style={{ marginBottom: 0 }}>
                      Linked Resident Reports ({totalReports})
                    </div>
                  </div>

                  {totalReports > 0 ? (
                    <>
                      {visibleReports.map((r) => (
                        <div
                          key={r.reportId}
                          className="pdm-report-row"
                          onClick={() => setSelectedReportId(r.reportId)}
                          role="button"
                          tabIndex={0}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' || e.key === ' ') {
                              e.preventDefault();
                              setSelectedReportId(r.reportId);
                            }
                          }}
                        >
                          <div className="pdm-report-row-left">
                            <span className="pdm-report-id-label">
                              <span className="pdm-report-id-prefix">Report ID:</span>
                              {r.reportId}
                            </span>
                          </div>
                          <svg className="pdm-report-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="9 18 15 12 9 6" />
                          </svg>
                        </div>
                      ))}

                      {remainingReports > 0 && (
                        <button
                          type="button"
                          className="pdm-view-all-btn"
                          onClick={() => setShowAllReports(true)}
                        >
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                          </svg>
                          View all +{remainingReports} reports
                        </button>
                      )}
                    </>
                  ) : (
                    <div className="pdm-no-reports">
                      No resident reports linked to this problem yet.
                    </div>
                  )}
                </div>
              </>
            )}
          </div>


        </div>
      </div>

      {/* Level 2: Individual Report Detail (from visible reports) */}
      {selectedReportId && !showAllReports && (
        <ReportDetailPopup
          token={token}
          reportId={selectedReportId}
          onClose={() => setSelectedReportId(null)}
          zLevel="l2"
        />
      )}

      {/* Level 2: All Reports List Popup */}
      {showAllReports && problem && (
        <AllReportsPopup
          token={token}
          reports={problem.relatedReports}
          onClose={() => setShowAllReports(false)}
        />
      )}
    </>
  );
};
