import React, { useState, useEffect } from 'react';
import type { User } from '../../types/auth';
import type {
  UncertainReportResponse,
  NearbyCandidateProblemSummary,
  LinkUncertainReportRequest,
  CreateProblemFromUncertainReportRequest,
} from '../../types/problems';
import {
  getUncertainReports,
  linkUncertainReport,
  createProblemFromUncertainReport,
  cancelUncertainReport,
} from '../../services/problemApi';
import { useNavigate } from 'react-router-dom';
import { Header } from '../../components/common';
import { ProblemDetailModal } from './ProblemDetailModal';
import { ROUTES } from '../../routes/paths';
import './UncertainReportsPage.css';

export interface UncertainReportsPageProps {
  currentUser?: User | null;
  token?: string | null;
  onNavigateToProblems?: () => void;
  onNavigateToReports?: () => void;
  onLogout?: () => void;
  onOpenProfile?: () => void;
}

const REPORTS_PER_PAGE = 3;
const MAX_PROBLEMS_SHOWN = 10;
const MAX_DISTANCE_METERS = 1000; // 1km radius

export const UncertainReportsPage: React.FC<UncertainReportsPageProps> = ({
  currentUser,
  token,
  onNavigateToProblems,
  onNavigateToReports,
  onLogout,
  onOpenProfile,
}) => {
  let navigate: (to: string) => void = () => {};
  try {
    navigate = useNavigate();
  } catch {
    // Tests outside router
  }

  const goToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));
  const goToReports = onNavigateToReports || (() => navigate(ROUTES.REPORTS));
  const goToProfile = onOpenProfile || (() => navigate(ROUTES.PROFILE));
  const [reports, setReports] = useState<UncertainReportResponse[]>([]);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successToast, setSuccessToast] = useState<string | null>(null);

  // ProblemDetailModal state
  const [viewingProblemId, setViewingProblemId] = useState<string | null>(null);

  // All Candidate Problems Modal state
  const [viewingAllCandidatesReport, setViewingAllCandidatesReport] = useState<UncertainReportResponse | null>(null);

  // Link Modal states
  const [linkingReport, setLinkingReport] = useState<UncertainReportResponse | null>(null);
  const [selectedProblemId, setSelectedProblemId] = useState<string>('');
  const [coordinatorNotes, setCoordinatorNotes] = useState<string>('');

  // Create Modal states
  const [creatingForReport, setCreatingForReport] = useState<UncertainReportResponse | null>(null);
  const [newTitle, setNewTitle] = useState<string>('');
  const [newDescription, setNewDescription] = useState<string>('');
  const [newCategory, setNewCategory] = useState<string>('ROAD');
  const [newAddress, setNewAddress] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [cancellingReportId, setCancellingReportId] = useState<string | null>(null);
  const [confirmingCancelReport, setConfirmingCancelReport] = useState<UncertainReportResponse | null>(null);

  const authToken = token || localStorage.getItem('mehewara_token') || '';

  const loadUncertainReports = () => {
    setIsLoading(true);
    setErrorMessage(null);

    getUncertainReports(authToken)
      .then((data) => {
        setReports(data || []);
        setIsLoading(false);
      })
      .catch((err: unknown) => {
        setErrorMessage(err instanceof Error ? err.message : 'Failed to load uncertain reports.');
        setIsLoading(false);
      });
  };

  useEffect(() => {
    loadUncertainReports();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  // Handle Toast Auto-Dismiss
  useEffect(() => {
    if (successToast) {
      const timer = setTimeout(() => setSuccessToast(null), 4000);
      return () => clearTimeout(timer);
    }
  }, [successToast]);

  useEffect(() => {
    if (errorMessage) {
      const timer = setTimeout(() => setErrorMessage(null), 5000);
      return () => clearTimeout(timer);
    }
  }, [errorMessage]);

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  /** Filter candidates to within 1km, limit to 10 total */
  const getFilteredCandidates = (candidates: NearbyCandidateProblemSummary[]) => {
    return candidates
      .filter((c) => c.distanceMeters <= MAX_DISTANCE_METERS)
      .slice(0, MAX_PROBLEMS_SHOWN);
  };

  // ─── Pagination Calculations ─────────────────────────────────────────────────
  const totalReports = reports.length;
  const totalPages = Math.max(1, Math.ceil(totalReports / REPORTS_PER_PAGE));

  // Auto-clamp current page if reports change (e.g. after linking or problem creation)
  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const startIndex = (currentPage - 1) * REPORTS_PER_PAGE;
  const paginatedReports = reports.slice(startIndex, startIndex + REPORTS_PER_PAGE);

  // ─── Modal Actions ────────────────────────────────────────────────────────────

  const handleOpenLinkModal = (report: UncertainReportResponse, candidateId?: string) => {
    setLinkingReport(report);
    setSelectedProblemId(candidateId || (report.nearbyCandidates[0]?.problemId ?? ''));
    setCoordinatorNotes('');
  };

  const handleConfirmLink = async () => {
    if (!linkingReport || !selectedProblemId) return;

    setIsSubmitting(true);
    try {
      const payload: LinkUncertainReportRequest = {
        reportId: linkingReport.reportId,
        problemId: selectedProblemId,
        coordinatorNotes: coordinatorNotes.trim() || undefined,
      };

      await linkUncertainReport(authToken, payload);

      setSuccessToast(`Report linked to Problem successfully! Centroid & summary updated.`);
      setLinkingReport(null);
      setReports((prev) => prev.filter((r) => r.reportId !== linkingReport.reportId));
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to link report.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleOpenCreateModal = (report: UncertainReportResponse) => {
    setCreatingForReport(report);
    setNewTitle(`Issue at ${report.address || 'Reported Location'}`);
    setNewDescription(report.description);
    setNewCategory(report.category);
    setNewAddress(report.address || '');
    setCoordinatorNotes('');
  };

  const handleConfirmCreate = async () => {
    if (!creatingForReport || !newTitle.trim()) return;

    setIsSubmitting(true);
    try {
      const payload: CreateProblemFromUncertainReportRequest = {
        reportId: creatingForReport.reportId,
        title: newTitle.trim(),
        description: newDescription.trim() || undefined,
        category: newCategory,
        latitude: creatingForReport.latitude,
        longitude: creatingForReport.longitude,
        address: newAddress.trim() || undefined,
        coordinatorNotes: coordinatorNotes.trim() || undefined,
      };

      const res = await createProblemFromUncertainReport(authToken, payload);

      setSuccessToast(`New Problem "${res.title}" created successfully!`);
      setCreatingForReport(null);
      setReports((prev) => prev.filter((r) => r.reportId !== creatingForReport.reportId));
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to create problem.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleConfirmCancel = async () => {
    if (!confirmingCancelReport) return;
    const targetReportId = confirmingCancelReport.reportId;

    setCancellingReportId(targetReportId);
    try {
      await cancelUncertainReport(authToken, targetReportId);
      setSuccessToast('Report has been cancelled successfully.');
      setReports((prev) => prev.filter((r) => r.reportId !== targetReportId));
      setConfirmingCancelReport(null);
    } catch (err: unknown) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to cancel report.');
    } finally {
      setCancellingReportId(null);
    }
  };

  // ─── Category Badge Class ─────────────────────────────────────────────────────

  const getCategoryClass = (category: string) => {
    const c = category.toUpperCase();
    if (c === 'ROAD') return 'urp-cat-road';
    if (c === 'DRAINAGE') return 'urp-cat-drainage';
    if (c === 'WASTE') return 'urp-cat-waste';
    if (c === 'ELECTRICAL') return 'urp-cat-electrical';
    if (c === 'ENVIRONMENT') return 'urp-cat-environment';
    return 'urp-cat-road';
  };

  return (
    <div className="problems-dashboard-container urp-container">
      <div className="problems-content-wrap">
        <Header
          currentUser={currentUser}
          onBrandClick={goToProblems}
          onLogout={onLogout}
          onOpenProfile={goToProfile}
        />

        <main className="urp-main">
          {/* Page Header */}
          <div className="urp-header-strip">
            <div className="urp-header-left">
              <div className="urp-title-row">
                <button
                  type="button"
                  className="urp-back-btn"
                  onClick={goToProblems}
                  aria-label="Back to Problems Dashboard"
                  title="Back to Problems Dashboard"
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <polyline points="15 18 9 12 15 6" />
                  </svg>
                </button>
                <h1 className="urp-page-title">Uncertain Reports Triage</h1>
              </div>
            </div>
          </div>

        {/* Toast Notifications */}
        {successToast && (
          <div className="urp-toast urp-toast-success">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
              <polyline points="22 4 12 14.01 9 11.01" />
            </svg>
            {successToast}
          </div>
        )}
        {errorMessage && (
          <div className="urp-toast urp-toast-error">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            {errorMessage}
          </div>
        )}

        {/* Content Area */}
        {isLoading ? (
          <div className="urp-loading-state">
            <div className="urp-spinner" />
            <p>Scanning municipal records for uncertain reports...</p>
          </div>
        ) : reports.length === 0 ? (
          <div className="urp-empty-state">
            <div className="urp-empty-icon">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                <polyline points="22 4 12 14.01 9 11.01" />
              </svg>
            </div>
            <h2>All Reports Consolidated</h2>
            <p>No uncertain reports awaiting coordinator triage. AI Agent 2 has autonomously clustered all clear reports into municipal problems.</p>
            <button className="urp-empty-btn" onClick={goToProblems}>
              Return to Problems Dashboard
            </button>
          </div>
        ) : (
          <>
            <div className="urp-card-grid">
              {paginatedReports.map((report) => {
                const filteredCandidates = getFilteredCandidates(report.nearbyCandidates);
                const visibleCandidates = filteredCandidates.slice(0, 3);
                const hasMoreCandidates = filteredCandidates.length > 3;

                return (
                  <article key={report.reportId} className="urp-card">
                    {/* Card Header: Category + Timestamp */}
                    <div className="urp-card-header">
                      <span className={`urp-cat-pill ${getCategoryClass(report.category)}`}>
                        {report.category}
                      </span>
                      <span className="urp-timestamp">
                        {new Date(report.createdAt).toLocaleString('en-US', {
                          dateStyle: 'medium',
                          timeStyle: 'short',
                        })}
                      </span>
                    </div>

                    {/* Report Content */}
                    <div className="urp-card-body">
                      {/* Fixed-Height Description Section */}
                      <div className="urp-desc-section">
                        <h3 className="urp-report-desc" title={report.description}>
                          "{report.description}"
                        </h3>
                      </div>

                      {/* Fixed-Height Metadata Section */}
                      <div className="urp-card-meta">
                        <div className="urp-meta-row">
                          <svg className="urp-meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                            <circle cx="12" cy="10" r="3" />
                          </svg>
                          <span className="urp-meta-text" title={report.address || `${report.latitude.toFixed(4)}, ${report.longitude.toFixed(4)}`}>
                            {report.address || `${report.latitude.toFixed(4)}, ${report.longitude.toFixed(4)}`}
                          </span>
                        </div>
                        <div className="urp-meta-row">
                          <svg className="urp-meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                            <circle cx="12" cy="7" r="4" />
                          </svg>
                          <span className="urp-meta-text" title={report.residentName}>{report.residentName}</span>
                        </div>
                      </div>

                      {/* Fixed-Height Photo Evidence Section */}
                      <div className="urp-photos-section">
                        {report.photoUrls && report.photoUrls.length > 0 ? (
                          <div className="urp-photos-row">
                            {report.photoUrls.map((url, idx) => (
                              <img key={idx} src={url} alt="Evidence" className="urp-thumbnail" />
                            ))}
                          </div>
                        ) : (
                          <div className="urp-photos-empty">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                              <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
                              <circle cx="8.5" cy="8.5" r="1.5" />
                              <polyline points="21 15 16 10 5 21" />
                            </svg>
                            <span>No photo evidence attached</span>
                          </div>
                        )}
                      </div>

                      {/* Fixed-Height Nearby Candidate Problems Section */}
                      <div className="urp-candidates-wrapper">
                        {filteredCandidates.length > 0 ? (
                          <div className="urp-candidates-section">
                            <h4 className="urp-candidates-title">
                              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                                <circle cx="12" cy="10" r="3" />
                              </svg>
                              Nearby Active Problems ({filteredCandidates.length})
                            </h4>
                            <div className="urp-candidates-list">
                              {visibleCandidates.map((cand) => (
                                <div key={cand.problemId} className="urp-candidate-item">
                                  <button
                                    type="button"
                                    className="urp-candidate-info-btn"
                                    onClick={() => setViewingProblemId(cand.problemId)}
                                    title="Click to view full problem details"
                                  >
                                    <span className="urp-candidate-name">{cand.title}</span>
                                    <span className="urp-candidate-dist">
                                      {cand.distanceMeters.toFixed(0)}m away • {cand.reportCount} {cand.reportCount === 1 ? 'report' : 'reports'}
                                    </span>
                                  </button>
                                  <button
                                    type="button"
                                    className="urp-btn-quick-link"
                                    onClick={() => handleOpenLinkModal(report, cand.problemId)}
                                  >
                                    Link Here
                                  </button>
                                </div>
                              ))}
                            </div>
                            {hasMoreCandidates && (
                              <button
                                type="button"
                                className="urp-view-all-nearby-btn"
                                onClick={() => setViewingAllCandidatesReport(report)}
                                title={`View all ${filteredCandidates.length} nearby candidate problems`}
                              >
                                <span>View all {filteredCandidates.length} nearby problems</span>
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                                  <polyline points="9 18 15 12 9 6" />
                                </svg>
                              </button>
                            )}
                          </div>
                        ) : (
                          <div className="urp-no-candidates">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                              <circle cx="12" cy="12" r="10" />
                              <line x1="12" y1="16" x2="12" y2="12" />
                              <line x1="12" y1="8" x2="12.01" y2="8" />
                            </svg>
                            <span>No active problems found within 1km</span>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Fixed-Height Card Actions */}
                    <div className="urp-card-actions">
                      <button
                        type="button"
                        className="urp-btn-primary"
                        onClick={() => handleOpenCreateModal(report)}
                      >
                        + Create New Problem
                      </button>
                      <button
                        type="button"
                        className="urp-btn-cancel-report"
                        onClick={() => setConfirmingCancelReport(report)}
                        disabled={cancellingReportId === report.reportId}
                        title="Cancel this unnecessary report"
                      >
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                          <circle cx="12" cy="12" r="10" />
                          <line x1="15" y1="9" x2="9" y2="15" />
                          <line x1="9" y1="9" x2="15" y2="15" />
                        </svg>
                        <span>Cancel</span>
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>

            {/* Pagination Controls */}
            {totalReports > 0 && (
              <nav className="urp-pagination" aria-label="Uncertain reports pagination">
                <div className="urp-pagination-info">
                  Showing <strong>{startIndex + 1}</strong>–<strong>{Math.min(startIndex + REPORTS_PER_PAGE, totalReports)}</strong> of <strong>{totalReports}</strong> reports
                </div>
                <div className="urp-pagination-controls">
                  <button
                    type="button"
                    className="urp-pagination-btn urp-pagination-prev"
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    aria-label="Previous Page"
                  >
                    Previous
                  </button>

                  {Array.from({ length: totalPages }, (_, i) => i + 1).map((pageNum) => (
                    <button
                      key={pageNum}
                      type="button"
                      className={`urp-pagination-btn ${pageNum === currentPage ? 'active' : ''}`}
                      onClick={() => setCurrentPage(pageNum)}
                      aria-current={pageNum === currentPage ? 'page' : undefined}
                    >
                      {pageNum}
                    </button>
                  ))}

                  <button
                    type="button"
                    className="urp-pagination-btn urp-pagination-next"
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
      </main>
    </div>

      {/* ─── Problem Detail Modal (same as ProblemsPage) ───────────────────────── */}
      {viewingProblemId && (
        <ProblemDetailModal
          token={authToken}
          problemId={viewingProblemId}
          onClose={() => setViewingProblemId(null)}
        />
      )}

      {/* ─── MODAL: View All Nearby Candidate Problems (Top 10) ─────────────────── */}
      {viewingAllCandidatesReport && (
        <div className="urp-modal-overlay" onClick={() => setViewingAllCandidatesReport(null)}>
          <div className="urp-modal-box urp-all-candidates-modal" onClick={(e) => e.stopPropagation()}>
            <div className="urp-modal-header">
              <div>
                <h3 className="urp-modal-title">Nearby Active Problems</h3>
                <p className="urp-modal-sub">
                  Showing top {getFilteredCandidates(viewingAllCandidatesReport.nearbyCandidates).length} candidate problems within 1km of this report
                </p>
              </div>
              <button
                type="button"
                className="urp-modal-close"
                onClick={() => setViewingAllCandidatesReport(null)}
                aria-label="Close modal"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>

            <div className="urp-modal-candidates-list">
              {getFilteredCandidates(viewingAllCandidatesReport.nearbyCandidates).map((cand, idx) => (
                <div key={cand.problemId} className="urp-modal-candidate-card">
                  <button
                    type="button"
                    className="urp-modal-candidate-info"
                    onClick={() => setViewingProblemId(cand.problemId)}
                    title="Click to view full problem details"
                  >
                    <div className="urp-modal-cand-top">
                      <span className="urp-modal-cand-index">#{idx + 1}</span>
                      <span className={`urp-cat-pill ${getCategoryClass(cand.category)}`}>
                        {cand.category}
                      </span>
                      <span className="urp-modal-cand-distance">
                        {cand.distanceMeters.toFixed(0)}m away
                      </span>
                    </div>
                    <h4 className="urp-modal-cand-title">{cand.title}</h4>
                    <div className="urp-modal-cand-meta">
                      {cand.address && (
                        <span className="urp-modal-cand-address">
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                            <circle cx="12" cy="10" r="3" />
                          </svg>
                          {cand.address}
                        </span>
                      )}
                      <span className="urp-modal-cand-reports">
                        {cand.reportCount} {cand.reportCount === 1 ? 'report' : 'reports'}
                      </span>
                    </div>
                  </button>
                  <div className="urp-modal-cand-actions">
                    <button
                      type="button"
                      className="urp-btn-view-details"
                      onClick={() => setViewingProblemId(cand.problemId)}
                    >
                      View Details
                    </button>
                    <button
                      type="button"
                      className="urp-btn-quick-link"
                      onClick={() => {
                        const report = viewingAllCandidatesReport;
                        setViewingAllCandidatesReport(null);
                        handleOpenLinkModal(report, cand.problemId);
                      }}
                    >
                      Link Here
                    </button>
                  </div>
                </div>
              ))}
            </div>

            <div className="urp-modal-actions">
              <button
                type="button"
                className="urp-btn-ghost"
                onClick={() => setViewingAllCandidatesReport(null)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL: Link Report to Existing Problem ──────────────────────────── */}
      {linkingReport && (
        <div className="urp-modal-overlay">
          <div className="urp-modal-box">
            <div className="urp-modal-header">
              <h3 className="urp-modal-title">Link Report to Existing Problem</h3>
              <button className="urp-modal-close" onClick={() => setLinkingReport(null)}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>
            <p className="urp-modal-sub">
              Associating this report will automatically update the problem's GPS centroid and aggregate intelligence.
            </p>

            <div className="urp-form-group">
              <label>Select Target Problem</label>
              {linkingReport.nearbyCandidates.length > 0 ? (
                <select
                  value={selectedProblemId}
                  onChange={(e) => setSelectedProblemId(e.target.value)}
                  className="urp-select"
                >
                  <option value="">— Choose Problem —</option>
                  {linkingReport.nearbyCandidates.map((c) => (
                    <option key={c.problemId} value={c.problemId}>
                      {c.title} ({c.distanceMeters.toFixed(0)}m away)
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="text"
                  placeholder="Enter Target Problem ID (GUID)"
                  value={selectedProblemId}
                  onChange={(e) => setSelectedProblemId(e.target.value)}
                  className="urp-input"
                />
              )}
            </div>

            <div className="urp-form-group">
              <label>Coordinator Resolution Notes (Optional)</label>
              <textarea
                rows={3}
                placeholder="Explain why this report is linked to this problem..."
                value={coordinatorNotes}
                onChange={(e) => setCoordinatorNotes(e.target.value)}
                className="urp-textarea"
              />
            </div>

            <div className="urp-modal-actions">
              <button
                className="urp-btn-ghost"
                onClick={() => setLinkingReport(null)}
                disabled={isSubmitting}
              >
                Cancel
              </button>
              <button
                className="urp-btn-primary"
                onClick={handleConfirmLink}
                disabled={isSubmitting || !selectedProblemId}
              >
                {isSubmitting ? 'Linking...' : 'Confirm Link'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL: Create New Problem from Report ────────────────────────────── */}
      {creatingForReport && (
        <div className="urp-modal-overlay">
          <div className="urp-modal-box">
            <div className="urp-modal-header">
              <h3 className="urp-modal-title">Create New Municipal Problem</h3>
              <button className="urp-modal-close" onClick={() => setCreatingForReport(null)}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>
            <p className="urp-modal-sub">
              Create an authoritative Problem record from this report. This establishes a new incident in the system.
            </p>

            <div className="urp-form-group">
              <label>Problem Title</label>
              <input
                type="text"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                className="urp-input"
                required
              />
            </div>

            <div className="urp-form-group">
              <label>Category</label>
              <select
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value)}
                className="urp-select"
              >
                <option value="ROAD">Road</option>
                <option value="DRAINAGE">Drainage</option>
                <option value="WASTE">Waste</option>
                <option value="ELECTRICAL">Electrical</option>
                <option value="ENVIRONMENT">Environment</option>
              </select>
            </div>

            <div className="urp-form-group">
              <label>Initial Synthesized Description</label>
              <textarea
                rows={3}
                value={newDescription}
                onChange={(e) => setNewDescription(e.target.value)}
                className="urp-textarea"
              />
            </div>

            <div className="urp-form-group">
              <label>Address / Vicinity</label>
              <input
                type="text"
                value={newAddress}
                onChange={(e) => setNewAddress(e.target.value)}
                className="urp-input"
              />
            </div>

            <div className="urp-form-group">
              <label>Coordinator Resolution Notes</label>
              <input
                type="text"
                placeholder="e.g. Manually confirmed as standalone defect"
                value={coordinatorNotes}
                onChange={(e) => setCoordinatorNotes(e.target.value)}
                className="urp-input"
              />
            </div>

            <div className="urp-modal-actions">
              <button
                className="urp-btn-ghost"
                onClick={() => setCreatingForReport(null)}
                disabled={isSubmitting}
              >
                Cancel
              </button>
              <button
                className="urp-btn-primary"
                onClick={handleConfirmCreate}
                disabled={isSubmitting || !newTitle.trim()}
              >
                {isSubmitting ? 'Creating...' : 'Create Problem'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Cancellation Confirmation Modal */}
      {confirmingCancelReport && (
        <div
          className="urp-modal-overlay"
          onClick={() => !cancellingReportId && setConfirmingCancelReport(null)}
        >
          <div
            className="urp-modal-box urp-cancel-confirm-modal"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-labelledby="urp-cancel-modal-title"
          >
            <div className="urp-confirm-header">
              <div className="urp-confirm-icon-wrap">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                  <line x1="12" y1="9" x2="12" y2="13" />
                  <line x1="12" y1="17" x2="12.01" y2="17" />
                </svg>
              </div>
              <div className="urp-confirm-header-text">
                <h3 id="urp-cancel-modal-title" className="urp-confirm-title">Cancel Report</h3>
                <span className="urp-confirm-badge">Action Irreversible</span>
              </div>
            </div>

            <p className="urp-confirm-message">
              Are you sure you want to cancel the report, This will update the report status to CANCELLED and remove it from the triage queue.
            </p>

            <div className="urp-confirm-actions">
              <button
                type="button"
                className="urp-btn-cancel-back"
                onClick={() => setConfirmingCancelReport(null)}
                disabled={Boolean(cancellingReportId)}
              >
                Keep Report
              </button>
              <button
                type="button"
                className="urp-btn-confirm-cancel"
                onClick={handleConfirmCancel}
                disabled={Boolean(cancellingReportId)}
              >
                {cancellingReportId ? (
                  <>
                    <span className="urp-btn-spinner-white" />
                    <span>Cancelling...</span>
                  </>
                ) : (
                  <>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                      <circle cx="12" cy="12" r="10" />
                      <line x1="15" y1="9" x2="9" y2="15" />
                      <line x1="9" y1="9" x2="15" y2="15" />
                    </svg>
                    <span>Cancel Report</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
