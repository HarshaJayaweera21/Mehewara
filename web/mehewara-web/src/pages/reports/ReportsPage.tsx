import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { ReportSummaryResponse } from '../../types/reports';
import { getResidentReports, getAllReports } from '../../services/reportApi';
import { ReportCard } from '../../components/reports/ReportCard';
import { CreateReportModal } from '../../components/reports/CreateReportModal';
import { ReportDetailModal } from '../../components/reports/ReportDetailModal';
import { Header, HeroBanner, MetricsStrip } from '../../components/common';
import { OpsNavDrawer } from '../../components/common/OpsNavDrawer';
import { ROUTES } from '../../routes/paths';
import './ReportsPage.css';

interface ReportsPageProps {
  currentUser: User;
  token: string;
  onLogout?: () => void;
  onOpenProfile?: () => void;
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
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const handleLogout = onLogout || (() => navigate(ROUTES.LOGIN));
  const handleOpenProfile = onOpenProfile || (() => navigate(ROUTES.PROFILE));
  const handleNavigateToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));

  const isAdmin = currentUser.role === 'ADMIN';
  const [isNavDrawerOpen, setIsNavDrawerOpen] = useState(false);

  const tabParam = searchParams.get('tab');
  const initialTab = tabParam === 'coordinator-reports' && isAdmin ? 'coordinator-reports' : 'my-reports';
  const [activeTab, setActiveTab] = useState<'my-reports' | 'coordinator-reports'>(initialTab);

  useEffect(() => {
    const p = searchParams.get('tab');
    if (p === 'coordinator-reports' && isAdmin) {
      setActiveTab('coordinator-reports');
    } else if (p === 'my-reports') {
      setActiveTab('my-reports');
    }
  }, [searchParams, isAdmin]);

  const handleTabChange = (tab: 'my-reports' | 'coordinator-reports') => {
    setActiveTab(tab);
    setPage(1);
    try {
      const next = new URLSearchParams(searchParams);
      next.set('tab', tab);
      setSearchParams(Object.fromEntries(next.entries()));
    } catch {
      // outside router
    }
  };

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
  }, [token, activeTab, page, selectedStatus, searchQuery, setLoading, setError, setReports, setTotalPages, setTotalItems]);

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

  const reportMetrics = useMemo(() => {
    const total = totalItems || reports.length;
    const pending = reports.filter((r) => {
      const s = (r.status || '').toUpperCase();
      return s === 'SUBMITTED' || s === 'PENDING';
    }).length;
    const inProgress = reports.filter((r) => {
      const s = (r.status || '').toUpperCase();
      return s === 'IN_PROGRESS' || s === 'ASSIGNED' || s === 'PROCESSING';
    }).length;
    const resolved = reports.filter((r) => {
      const s = (r.status || '').toUpperCase();
      return s === 'RESOLVED' || s === 'CLOSED';
    }).length;
    return { total, pending, inProgress, resolved };
  }, [reports, totalItems]);

  return (
    <div className="reports-page-container">
      {/* Top Header */}
      <Header
        currentUser={currentUser}
        onLogout={handleLogout}
        onOpenProfile={handleOpenProfile}
        onBrandClick={() => navigate(isAdmin ? ROUTES.OPERATIONS : ROUTES.HOME)}
        roleBadgeText={isAdmin ? 'Municipal Coordinator' : 'Resident'}
        showName={true}
        showMenuButton={isAdmin}
        onMenuClick={() => setIsNavDrawerOpen(prev => !prev)}
        isMenuOpen={isNavDrawerOpen}
      />

      {isAdmin && (
        <OpsNavDrawer
          isOpen={isNavDrawerOpen}
          onClose={() => setIsNavDrawerOpen(false)}
          activePage="reports"
          onNavigateToDashboard={() => navigate(ROUTES.OPERATIONS)}
          onNavigateToProblems={handleNavigateToProblems}
          onNavigateToDispatch={() => navigate(ROUTES.DISPATCH)}
          onNavigateToCrews={() => navigate(ROUTES.CREWS)}
          onNavigateToWorkOrders={() => navigate(ROUTES.WORK_ORDERS)}
          onNavigateToReports={() => {}}
        />
      )}

      <div className="reports-content-wrap">

        {/* Hero Welcome Banner */}
        <HeroBanner
          badge={isAdmin ? 'CITIZEN REPORTS' : 'RESIDENT PORTAL'}
          title={isAdmin ? 'Citizen Defect Reports' : 'Resident Issue Tracker'}
          subtitle={
            isAdmin
              ? 'Centralized intake registry of citizen-submitted civic infrastructure defects, geocoded locations, triage statuses, and council workflows.'
              : 'Submit public infrastructure concerns, track council review milestones, and monitor municipal remediation progress in your community.'
          }
          ariaLabel={isAdmin ? 'Citizen Defect Reports Banner' : 'Resident Issue Tracker Banner'}
        />

        {/* Operational Metrics Strip for Coordinators */}
        {isAdmin && (
          <MetricsStrip
            items={[
              {
                id: 'total',
                label: 'Total Reports',
                value: reportMetrics.total,
                descriptor: 'Citizen defect submissions',
                hasPip: true,
              },
              {
                id: 'pending',
                label: 'Awaiting Triage',
                value: reportMetrics.pending,
                descriptor: 'New reports requiring evaluation',
                hasPip: true,
              },
              {
                id: 'in-progress',
                label: 'In Progress',
                value: reportMetrics.inProgress,
                descriptor: 'Active investigation or repair',
              },
              {
                id: 'resolved',
                label: 'Resolved / Closed',
                value: reportMetrics.resolved,
                descriptor: 'Defects verified resolved',
              },
            ]}
            ariaLabel="Key Reports Metrics"
          />
        )}

        {/* Consolidated Reports Toolbar */}
        <div className="reports-toolbar">
          <div className="reports-toolbar-left">
            {isAdmin && (
              <div className="reports-view-tabs" role="tablist" aria-label="Reports Views">
                <button
                  type="button"
                  className={`reports-tab-btn ${activeTab === 'my-reports' ? 'active' : ''}`}
                  onClick={() => handleTabChange('my-reports')}
                  role="tab"
                  aria-selected={activeTab === 'my-reports'}
                >
                  📋 My Reports
                </button>
                <button
                  type="button"
                  className={`reports-tab-btn ${activeTab === 'coordinator-reports' ? 'active' : ''}`}
                  onClick={() => handleTabChange('coordinator-reports')}
                  role="tab"
                  aria-selected={activeTab === 'coordinator-reports'}
                >
                  🏢 Coordinator All Reports
                </button>
              </div>
            )}
          </div>

          <div className="reports-toolbar-right">
            <button
              type="button"
              className="primary-add-report-btn"
              onClick={() => setIsCreateModalOpen(true)}
              title="Create a new infrastructure report"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <line x1="12" y1="5" x2="12" y2="19"/>
                <line x1="5" y1="12" x2="19" y2="12"/>
              </svg>
              <span>Report an Issue</span>
            </button>
          </div>
        </div>

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
