import React, { useState, useEffect, useCallback } from 'react';
import type { User } from '../../types/auth';
import type { ReportSummaryResponse } from '../../types/reports';
import { getResidentReports, getAllReports } from '../../services/reportApi';
import { ReportCard } from '../../components/reports/ReportCard';
import { CreateReportModal } from '../../components/reports/CreateReportModal';
import { ReportDetailModal } from '../../components/reports/ReportDetailModal';
import './ReportsPage.css';

interface ReportsPageProps {
  currentUser: User;
  token: string;
  onLogout: () => void;
  onOpenProfile: () => void;
  onNavigateToProblems?: () => void;
}

const STATUS_FILTERS = ['ALL', 'PENDING', 'PROCESSING', 'ASSIGNED', 'RESOLVED', 'CANCELLED'];

export const ReportsPage: React.FC<ReportsPageProps> = ({
  currentUser,
  token,
  onLogout,
  onOpenProfile,
  onNavigateToProblems,
}) => {
  const isAdmin = currentUser.role === 'ADMIN';

  const [activeTab, setActiveTab] = useState<'my-reports' | 'coordinator-reports'>('my-reports');
  const [reports, setReports] = useState<ReportSummaryResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successBanner, setSuccessBanner] = useState<string | null>(null);

  // Filters
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalItems, setTotalItems] = useState(0);

  // Modals
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [selectedDetailId, setSelectedDetailId] = useState<string | null>(null);

  const fetchReports = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const statusParam = selectedStatus !== 'ALL' ? selectedStatus : undefined;

      if (activeTab === 'my-reports') {
        const result = await getResidentReports(token, {
          page,
          pageSize: 12,
          status: statusParam,
        });
        setReports(result.items || []);
        setTotalPages(result.totalPages || 1);
        setTotalItems(result.totalItems || 0);
      } else {
        const result = await getAllReports(token, {
          page,
          pageSize: 12,
          status: statusParam,
          search: searchQuery.trim() || undefined,
        });
        setReports(result.items || []);
        setTotalPages(result.totalPages || 1);
        setTotalItems(result.totalItems || 0);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to fetch reports from backend.');
    } finally {
      setLoading(false);
    }
  }, [token, activeTab, page, selectedStatus, searchQuery]);

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

  return (
    <div className="reports-page-container">
      {/* Top Navbar */}
      <header className="reports-navbar">
        <div className="navbar-brand">
          <div className="brand-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
          </div>
          <div>
            <div className="brand-title">Mehewara</div>
            <div className="brand-subtitle">Municipal Operations & Resident Portal</div>
          </div>
        </div>

        <div className="navbar-actions">
          {isAdmin && (
            <div className="nav-tabs">
              <button
                type="button"
                className={`nav-tab-btn ${activeTab === 'my-reports' ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab('my-reports');
                  setPage(1);
                }}
              >
                📋 My Reports
              </button>
              <button
                type="button"
                className={`nav-tab-btn ${activeTab === 'coordinator-reports' ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab('coordinator-reports');
                  setPage(1);
                }}
              >
                🏢 Coordinator All Reports
              </button>
              {onNavigateToProblems && (
                <button
                  type="button"
                  className="nav-tab-btn"
                  onClick={onNavigateToProblems}
                  style={{ borderColor: '#123C32', color: '#123C32', fontWeight: 600 }}
                  title="Switch to Municipal Problems Dashboard"
                >
                  ⚡ Problems Dashboard
                </button>
              )}
            </div>
          )}

          {/* Sequential Button to Add Reports */}
          <button
            type="button"
            className="primary-add-report-btn"
            onClick={() => setIsCreateModalOpen(true)}
            title="Create a new infrastructure report"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            Report an Issue
          </button>

          {/* User Profile Pill */}
          <div className="user-profile-pill" onClick={onOpenProfile} style={{ cursor: 'pointer' }} title="View Profile">
            <div className="user-avatar-small">
              {currentUser.profileImageUrl ? (
                <img src={currentUser.profileImageUrl} alt={currentUser.name} />
              ) : (
                currentUser.name?.charAt(0).toUpperCase() || 'U'
              )}
            </div>
            <span className="user-name-small">{currentUser.name}</span>
            <span className="role-badge-small">{currentUser.role}</span>
          </div>

          <button type="button" className="signout-btn" onClick={onLogout} title="Sign Out">
            Sign Out
          </button>
        </div>
      </header>

      {/* Main Content */}
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

        {/* Header Title Section */}
        <div className="reports-header-section">
          <div>
            <h1 className="page-title">
              {activeTab === 'my-reports' ? 'My Reported Issues' : 'Municipal Reports Dashboard (Coordinator)'}
            </h1>
            <p className="page-desc">
              {activeTab === 'my-reports'
                ? 'Track the status, coordinates, and council repair progress of your submitted public issues.'
                : 'Review, filter, and inspect incoming citizen reports submitted across all municipal zones.'}
            </p>
          </div>

          <button
            type="button"
            className="primary-add-report-btn"
            onClick={() => setIsCreateModalOpen(true)}
          >
            ➕ Add New Report
          </button>
        </div>

        {/* Filters and Search Bar */}
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
            {activeTab === 'coordinator-reports' && (
              <div className="search-input-wrapper">
                <input
                  type="text"
                  placeholder="Search description/address..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      setPage(1);
                      fetchReports();
                    }
                  }}
                />
              </div>
            )}

            <button
              type="button"
              className="refresh-btn"
              onClick={fetchReports}
              disabled={loading}
              title="Refresh Reports"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="23 4 23 10 17 10"/>
                <polyline points="1 20 1 14 7 14"/>
                <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>
              </svg>
              {loading ? 'Refreshing...' : 'Refresh'}
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
                  onViewDetails={(id) => setSelectedDetailId(id)}
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
          onClose={() => setSelectedDetailId(null)}
        />
      )}
    </div>
  );
};
