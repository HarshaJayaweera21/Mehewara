import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, useSearchParams, Navigate } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { ReportSummaryResponse } from '../../types/reports';
import { getResidentReports } from '../../services/reportApi';
import { ReportCard } from '../../components/reports/ReportCard';
import { CreateReportModal } from '../../components/reports/CreateReportModal';
import { ReportDetailModal } from '../../components/reports/ReportDetailModal';
import { Header, HeroBanner } from '../../components/common';
import { ROUTES } from '../../routes/paths';
import './ReportsPage.css';

interface ReportsPageProps {
  currentUser: User;
  token: string;
  onLogout?: () => void;
  onOpenProfile?: () => void;
}

const STATUS_FILTERS = ['ALL', 'PENDING', 'PROCESSING', 'ASSIGNED', 'RESOLVED', 'CANCELLED'];

export const ReportsPage: React.FC<ReportsPageProps> = ({
  currentUser,
  token,
  onLogout,
  onOpenProfile,
}) => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const handleLogout = onLogout || (() => navigate(ROUTES.LOGIN));
  const handleOpenProfile = onOpenProfile || (() => navigate(ROUTES.PROFILE));

  const isAdmin = currentUser.role === 'ADMIN';

  const [reports, setReports] = useState<ReportSummaryResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successBanner, setSuccessBanner] = useState<string | null>(null);

  // Filters
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalItems, setTotalItems] = useState(0);

  // Modals
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const reportIdParam = searchParams.get('reportId');
  const [selectedDetailId, setSelectedDetailId] = useState<string | null>(reportIdParam);

  useEffect(() => {
    const p = searchParams.get('reportId');
    if (p !== selectedDetailId) {
      setSelectedDetailId(p);
    }
  }, [searchParams, selectedDetailId]);

  const handleOpenDetail = (id: string) => {
    setSelectedDetailId(id);
    try {
      const next = new URLSearchParams(searchParams);
      next.set('reportId', id);
      setSearchParams(Object.fromEntries(next.entries()));
    } catch {
      // outside router
    }
  };

  const handleCloseDetail = () => {
    setSelectedDetailId(null);
    try {
      const next = new URLSearchParams(searchParams);
      next.delete('reportId');
      setSearchParams(Object.fromEntries(next.entries()));
    } catch {
      // outside router
    }
  };

  const fetchReports = useCallback(async () => {
    if (isAdmin) return;
    try {
      setLoading(true);
      setError(null);

      const statusParam = selectedStatus !== 'ALL' ? selectedStatus : undefined;

      const result = await getResidentReports(token, {
        page,
        pageSize: 12,
        status: statusParam,
      });
      setReports(result.items || []);
      setTotalPages(result.totalPages || 1);
      setTotalItems(result.totalItems || 0);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to fetch reports from backend.');
    } finally {
      setLoading(false);
    }
  }, [token, isAdmin, page, selectedStatus]);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  const handleReportCreated = (newReport: { id: string }) => {
    setIsCreateModalOpen(false);
    setSuccessBanner(`Report successfully submitted to Mehewara council! (ID: ${newReport.id})`);
    setTimeout(() => setSuccessBanner(null), 8000);
    // Refresh reports list
    setPage(1);
    fetchReports();
  };

  // Coordinators inspect defect reports grouped by problem on the Municipal Problems Board
  if (isAdmin) {
    return <Navigate to={ROUTES.PROBLEMS} replace />;
  }

  return (
    <div className="reports-page-container">
      <div className="reports-content-wrap">
        {/* Top Header */}
        <Header
          currentUser={currentUser}
          onLogout={handleLogout}
          onOpenProfile={handleOpenProfile}
          onBrandClick={() => navigate(ROUTES.HOME)}
          roleBadgeText="Resident"
          showName={true}
          showMenuButton={false}
        />

        {/* Hero Welcome Banner */}
        <HeroBanner
          badge="RESIDENT PORTAL"
          title="Resident Issue Tracker"
          subtitle="Submit public infrastructure concerns, track council review milestones, and monitor municipal remediation progress in your community."
          ariaLabel="Resident Issue Tracker Banner"
        />

        {/* Main Content Area */}
        <main className="reports-main-content">
          {/* Success Banner */}
          {successBanner && (
            <div className="success-banner" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span>{successBanner}</span>
              <button
                type="button"
                onClick={() => setSuccessBanner(null)}
                style={{ background: 'transparent', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '1.2rem' }}
              >
                &times;
              </button>
            </div>
          )}

          {/* Error Banner */}
          {error && <div className="error-banner">{error}</div>}

          {/* Merged Filters & Action Toolbar */}
          <div className="reports-filter-bar">
            <div className="filter-group">
              <span className="filter-label">Status Filter:</span>
              <div className="status-filter-pills">
                {STATUS_FILTERS.map((s) => (
                  <button
                    type="button"
                    key={s}
                    className={`status-filter-btn ${selectedStatus === s ? 'active' : ''}`}
                    onClick={() => {
                      setSelectedStatus(s);
                      setPage(1);
                    }}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>

            <div className="filter-group">
              <button
                type="button"
                className="primary-add-report-btn"
                onClick={() => setIsCreateModalOpen(true)}
                title="Create a new infrastructure report"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <line x1="12" y1="5" x2="12" y2="19" />
                  <line x1="5" y1="12" x2="19" y2="12" />
                </svg>
                <span>Report an Issue</span>
              </button>
            </div>
          </div>

        {/* Loading Spinner */}
        {loading && (
          <div style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
            <span className="spinner" style={{ width: '24px', height: '24px', borderWidth: '3px' }}></span>
            <div style={{ marginTop: '0.75rem', fontSize: '0.9rem' }}>Loading reports from backend...</div>
          </div>
        )}

        {/* Reports Grid */}
        {!loading && reports.length > 0 && (
          <>
            <div className="reports-grid">
              {reports.map((report) => (
                <ReportCard
                  key={report.id}
                  report={report}
                  onViewDetails={(id) => handleOpenDetail(id)}
                />
              ))}
            </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="pagination-bar">
                <button
                  type="button"
                  className="page-btn"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  ← Previous
                </button>
                <span className="page-info">
                  Page {page} of {totalPages} ({totalItems} total)
                </span>
                <button
                  type="button"
                  className="page-btn"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next →
                </button>
              </div>
            )}
          </>
        )}

        {/* Empty State */}
        {!loading && reports.length === 0 && (
          <div className="empty-reports-container">
            <div className="empty-icon">📋</div>
            <h3 className="empty-title">No Reports Found</h3>
            <p className="empty-subtitle">
              {selectedStatus !== 'ALL'
                ? `There are currently no reports with status "${selectedStatus}".`
                : 'You have not submitted any public infrastructure reports yet. Notice a broken streetlight, pothole, or water leak in your neighborhood?'}
            </p>
            <button
              type="button"
              className="primary-add-report-btn"
              style={{ margin: '0 auto' }}
              onClick={() => setIsCreateModalOpen(true)}
            >
              ➕ Submit Your First Report
            </button>
          </div>
        )}
      </main>
      </div>


      {/* Create Report Modal */}
      {isCreateModalOpen && (
        <CreateReportModal
          token={token}
          onClose={() => setIsCreateModalOpen(false)}
          onSuccess={handleReportCreated}
        />
      )}

      {/* Report Detail Modal */}
      {selectedDetailId && (
        <ReportDetailModal
          token={token}
          reportId={selectedDetailId}
          onClose={handleCloseDetail}
        />
      )}
    </div>
  );
};
