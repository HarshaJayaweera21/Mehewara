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
} from '../../services/problemApi';
import { Header } from '../../components/common';
import { ProblemDetailModal } from './ProblemDetailModal';
import './UncertainReportsPage.css';

export interface UncertainReportsPageProps {
  currentUser?: User | null;
  token?: string | null;
  onNavigateToProblems: () => void;
  onNavigateToReports?: () => void;
  onLogout?: () => void;
  onOpenProfile?: () => void;
}

const INITIAL_PROBLEMS_SHOWN = 3;
const MAX_PROBLEMS_SHOWN = 10;
const MAX_DISTANCE_METERS = 1000; // 1km radius

export const UncertainReportsPage: React.FC<UncertainReportsPageProps> = ({
  currentUser,
  token,
  onNavigateToProblems,
  onLogout,
  onOpenProfile,
}) => {
  const [reports, setReports] = useState<UncertainReportResponse[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successToast, setSuccessToast] = useState<string | null>(null);

  // Per-card "show all problems" toggle: reportId -> boolean
  const [expandedCandidates, setExpandedCandidates] = useState<Record<string, boolean>>({});

  // ProblemDetailModal state
  const [viewingProblemId, setViewingProblemId] = useState<string | null>(null);

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
  }, [token]);

  // Handle Toast Auto-Dismiss
  useEffect(() => {
    if (successToast) {
      const timer = setTimeout(() => setSuccessToast(null), 4000);
      return () => clearTimeout(timer);
    }
  }, [successToast]);

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  /** Filter candidates to within 1km, limit to 10 total */
  const getFilteredCandidates = (candidates: NearbyCandidateProblemSummary[]) => {
    return candidates
      .filter((c) => c.distanceMeters <= MAX_DISTANCE_METERS)
      .slice(0, MAX_PROBLEMS_SHOWN);
  };

  /** Get visible candidates based on expanded state */
  const getVisibleCandidates = (reportId: string, candidates: NearbyCandidateProblemSummary[]) => {
    const filtered = getFilteredCandidates(candidates);
    const isExpanded = expandedCandidates[reportId] || false;
    return isExpanded ? filtered : filtered.slice(0, INITIAL_PROBLEMS_SHOWN);
  };

  const toggleExpandCandidates = (reportId: string) => {
    setExpandedCandidates((prev) => ({ ...prev, [reportId]: !prev[reportId] }));
  };

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
    <div className="urp-container">
      <Header
        currentUser={currentUser}
        onBrandClick={onNavigateToProblems}
        onLogout={onLogout}
        onOpenProfile={onOpenProfile}
      />

      <main className="urp-main">
        {/* Page Header */}
        <div className="urp-header-strip">
          <div className="urp-header-left">
            <button className="urp-back-btn" onClick={onNavigateToProblems}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="15 18 9 12 15 6" />
              </svg>
              Back to Problems Dashboard
            </button>
            <div className="urp-title-group">
              <h1 className="urp-page-title">Uncertain Reports Triage</h1>
              <span className="urp-badge-count">{reports.length} Awaiting Review</span>
            </div>
            <p className="urp-subtitle">
              Resident reports flagged as <strong>UNCERTAIN</strong> by AI consolidation due to ambiguous locations, competing candidate clusters, or borderline evidence.
            </p>
          </div>
          <button
            className="urp-refresh-btn"
            onClick={loadUncertainReports}
            disabled={isLoading}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="23 4 23 10 17 10" />
              <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
            </svg>
            Refresh
          </button>
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
            <button className="urp-empty-btn" onClick={onNavigateToProblems}>
              Return to Problems Dashboard
            </button>
          </div>
        ) : (
          <div className="urp-card-grid">
            {reports.map((report) => {
              const filteredCandidates = getFilteredCandidates(report.nearbyCandidates);
              const visibleCandidates = getVisibleCandidates(report.reportId, report.nearbyCandidates);
              const hasMore = filteredCandidates.length > INITIAL_PROBLEMS_SHOWN;
              const isExpanded = expandedCandidates[report.reportId] || false;

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
                    <h3 className="urp-report-desc">"{report.description}"</h3>

                    <div className="urp-card-meta">
                      <div className="urp-meta-row">
                        <svg className="urp-meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                          <circle cx="12" cy="10" r="3" />
                        </svg>
                        <span className="urp-meta-text">
                          {report.address || `${report.latitude.toFixed(4)}, ${report.longitude.toFixed(4)}`}
                        </span>
                      </div>
                      <div className="urp-meta-row">
                        <svg className="urp-meta-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                          <circle cx="12" cy="7" r="4" />
                        </svg>
                        <span className="urp-meta-text">{report.residentName}</span>
                      </div>
                    </div>

                    {/* Photo Thumbnails */}
                    {report.photoUrls.length > 0 && (
                      <div className="urp-photos-row">
                        {report.photoUrls.map((url, idx) => (
                          <img key={idx} src={url} alt="Evidence" className="urp-thumbnail" />
                        ))}
                      </div>
                    )}

                    {/* Nearby Candidate Problems */}
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
                                className="urp-btn-quick-link"
                                onClick={() => handleOpenLinkModal(report, cand.problemId)}
                              >
                                Link Here
                              </button>
                            </div>
                          ))}
                        </div>
                        {hasMore && (
                          <button
                            type="button"
                            className="urp-view-all-problems-btn"
                            onClick={() => toggleExpandCandidates(report.reportId)}
                          >
                            {isExpanded
                              ? 'Show fewer problems'
                              : `View all ${filteredCandidates.length} problems`}
                            <svg
                              width="12" height="12"
                              viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"
                              className={isExpanded ? 'urp-chevron-up' : ''}
                            >
                              <polyline points="6 9 12 15 18 9" />
                            </svg>
                          </button>
                        )}
                      </div>
                    ) : (
                      <div className="urp-no-candidates">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <circle cx="12" cy="12" r="10" />
                          <line x1="12" y1="16" x2="12" y2="12" />
                          <line x1="12" y1="8" x2="12.01" y2="8" />
                        </svg>
                        No existing active problems found within 1km radius
                      </div>
                    )}
                  </div>

                  {/* Card Actions */}
                  <div className="urp-card-actions">
                    <button
                      className="urp-btn-secondary"
                      onClick={() => handleOpenLinkModal(report)}
                    >
                      Link to Problem...
                    </button>
                    <button
                      className="urp-btn-primary"
                      onClick={() => handleOpenCreateModal(report)}
                    >
                      + Create New Problem
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </main>

      {/* ─── Problem Detail Modal (same as ProblemsPage) ───────────────────────── */}
      {viewingProblemId && (
        <ProblemDetailModal
          token={authToken}
          problemId={viewingProblemId}
          onClose={() => setViewingProblemId(null)}
        />
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
    </div>
  );
};
