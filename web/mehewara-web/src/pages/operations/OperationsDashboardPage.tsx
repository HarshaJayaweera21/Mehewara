import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { ProblemResponse } from '../../types/problems';
import type { ReportSummaryResponse } from '../../types/reports';
import type { RecommendationListItem } from '../../types/dispatch';
import { getAllReports } from '../../services/reportApi';
import { getProblems, getUncertainReports } from '../../services/problemApi';
import { getCrews } from '../../services/crewApi';
import { getRecommendations } from '../../services/dispatchApi';
import { getWorkOrders } from '../../services/workOrdersApi';
import { ROUTES } from '../../routes/paths';
import { Icon } from '../../design-system/mehewara/Icon';
import { Header, OpsNavDrawer, HeroBanner, MetricsStrip } from '../../components/common';
import './OperationsDashboardPage.css';

interface OperationsDashboardPageProps {
  currentUser: User;
  token: string;
  onLogout?: () => void;
  onOpenProfile?: () => void;
  onNavigateToReports?: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToUncertainReports?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
  onNavigateToWorkOrders?: () => void;
}

interface DashboardData {
  reports: ReportSummaryResponse[];
  problems: ProblemResponse[];
  recommendations: RecommendationListItem[];
  reportCount: number | null;
  pendingReportCount: number | null;
  problemCount: number | null;
  crewCount: number | null;
  recommendationCount: number | null;
  workOrderCount: number | null;
  uncertainCount: number | null;
  errors: string[];
}

const emptyData: DashboardData = {
  reports: [], problems: [], recommendations: [], reportCount: null,
  pendingReportCount: null, problemCount: null, crewCount: null,
  recommendationCount: null, workOrderCount: null, uncertainCount: null, errors: [],
};

const label = (value: string) => value.replaceAll('_', ' ').toLowerCase().replace(/\b\w/g, c => c.toUpperCase());
const count = (value: number | null, loading: boolean) => loading ? '…' : value === null ? '—' : value.toLocaleString();
const relativeTime = (value: string) => {
  const minutes = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 60000));
  if (!Number.isFinite(minutes)) return '';
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h ago`;
  return `${Math.floor(minutes / 1440)}d ago`;
};

export function OperationsDashboardPage({
  currentUser, token, onLogout, onOpenProfile, onNavigateToReports,
  onNavigateToProblems, onNavigateToUncertainReports, onNavigateToDispatch,
  onNavigateToCrews, onNavigateToWorkOrders,
}: OperationsDashboardPageProps) {
  const navigate = useNavigate();
  const [isNavDrawerOpen, setIsNavDrawerOpen] = useState(false);

  const goToReports = onNavigateToReports || (() => navigate(ROUTES.REPORTS));
  const goToProblems = onNavigateToProblems || (() => navigate(ROUTES.PROBLEMS));
  const goToUncertainReports = onNavigateToUncertainReports || (() => navigate(ROUTES.UNCERTAIN_REPORTS));
  const goToDispatch = onNavigateToDispatch || (() => navigate(ROUTES.DISPATCH));
  const goToCrews = onNavigateToCrews || (() => navigate(ROUTES.CREWS));
  const goToWorkOrders = onNavigateToWorkOrders || (() => navigate(ROUTES.WORK_ORDERS));
  const goToProfile = onOpenProfile || (() => navigate(ROUTES.PROFILE));
  const handleSignOut = onLogout || (() => {
    localStorage.removeItem('mehewara_token');
    localStorage.removeItem('mehewara_user');
    navigate(ROUTES.LOGIN);
  });

  const [data, setData] = useState<DashboardData>(emptyData);
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);
  const [search, setSearch] = useState('');

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      const results = await Promise.allSettled([
        getAllReports(token, { page: 1, pageSize: 4, sortBy: 'createdAt', sortDirection: 'desc' }),
        getAllReports(token, { page: 1, pageSize: 1, status: 'PENDING' }),
        getProblems(token, { page: 1, pageSize: 100, sortBy: 'priority', sortDirection: 'desc' }),
        getCrews(token, { page: 1, pageSize: 1 }),
        getRecommendations(token, { page: 1, pageSize: 4, reviewBucket: 'READY' }),
        getWorkOrders(token, true, { page: 1, pageSize: 1 }),
        getUncertainReports(token),
      ]);
      if (!active) return;
      const next: DashboardData = { ...emptyData, errors: [] };
      const names = ['reports', 'pending reports', 'problems', 'crews', 'recommendations', 'work orders', 'uncertain reports'];
      results.forEach((result, index) => {
        if (result.status === 'rejected') next.errors.push(names[index]);
      });
      if (results[0].status === 'fulfilled') {
        next.reports = results[0].value.items ?? [];
        next.reportCount = results[0].value.totalItems;
      }
      if (results[1].status === 'fulfilled') next.pendingReportCount = results[1].value.totalItems;
      if (results[2].status === 'fulfilled') {
        next.problems = results[2].value.items ?? [];
        next.problemCount = results[2].value.totalItems;
      }
      if (results[3].status === 'fulfilled') next.crewCount = results[3].value.totalItems;
      if (results[4].status === 'fulfilled') {
        next.recommendations = results[4].value.items ?? [];
        next.recommendationCount = results[4].value.totalItems;
      }
      if (results[5].status === 'fulfilled') next.workOrderCount = results[5].value.totalItems;
      if (results[6].status === 'fulfilled') next.uncertainCount = results[6].value.length;
      setData(next);
      setLoading(false);
    };
    void load();
    return () => { active = false; };
  }, [token, refreshKey]);

  const priorityProblems = useMemo(() => data.problems
    .filter(problem => ['CRITICAL', 'HIGH'].includes((problem.priority ?? '').toUpperCase()) && !['RESOLVED', 'CLOSED'].includes(problem.status.toUpperCase()))
    .sort((a, b) => Number(b.priority === 'CRITICAL') - Number(a.priority === 'CRITICAL'))
    .slice(0, 3), [data.problems]);
  const query = search.trim().toLowerCase();
  const shownProblems = priorityProblems.filter(problem => `${problem.title} ${problem.address ?? ''}`.toLowerCase().includes(query));
  const shownReports = data.reports.filter(report => `${report.description} ${report.address ?? ''} ${report.category}`.toLowerCase().includes(query));
  const shownRecommendations = data.recommendations.filter(item => `${item.problemTitle} ${item.recommendationReason}`.toLowerCase().includes(query));

  return (
    <div className="ops-page-container">
      <Header
        currentUser={currentUser}
        onLogout={handleSignOut}
        onOpenProfile={goToProfile}
        onBrandClick={() => navigate(ROUTES.OPERATIONS)}
        roleBadgeText="Municipal Coordinator"
        showName={true}
        showMenuButton={true}
        onMenuClick={() => setIsNavDrawerOpen(prev => !prev)}
        isMenuOpen={isNavDrawerOpen}
      />

      <OpsNavDrawer
        isOpen={isNavDrawerOpen}
        onClose={() => setIsNavDrawerOpen(false)}
        activePage="dashboard"
        pendingDispatchCount={data.recommendationCount ?? 0}
        onNavigateToDashboard={() => navigate(ROUTES.OPERATIONS)}
        onNavigateToProblems={goToProblems}
        onNavigateToUncertainReports={goToUncertainReports}
        onNavigateToDispatch={goToDispatch}
        onNavigateToCrews={goToCrews}
        onNavigateToWorkOrders={goToWorkOrders}
        onNavigateToReports={goToReports}
      />

      <div className="ops-content-wrap">

        {/* 2. Operations Welcome Banner */}
        <HeroBanner
          badge="OPERATIONS SUITE"
          title="Operations Command Desk"
          subtitle="Centralized operational overview across municipal defects, crew deployments, and active field resolutions."
          ariaLabel="Operations Command Desk Banner"
        />

        {/* 3. Operational Metrics Strip */}
        <MetricsStrip
          items={[
            {
              id: 'reports',
              label: 'Reports',
              value: count(data.reportCount, loading),
              descriptor: `${count(data.pendingReportCount, loading)} awaiting processing`,
              hasPip: true,
              onClick: goToReports,
            },
            {
              id: 'problems',
              label: 'Problems status',
              value: count(data.problemCount, loading),
              descriptor: 'Total recorded problems',
              hasPip: true,
              onClick: goToProblems,
            },
            {
              id: 'crews',
              label: 'Crew dispatch',
              value: count(data.crewCount, loading),
              descriptor: 'Municipal field teams',
              hasPip: true,
              onClick: goToCrews,
            },
            {
              id: 'recommendations',
              label: 'AI recommendations',
              value: count(data.recommendationCount, loading),
              descriptor: 'Ready for review',
              hasPip: true,
              onClick: goToDispatch,
            },
            {
              id: 'work-orders',
              label: 'Work orders',
              value: count(data.workOrderCount, loading),
              descriptor: 'Total work orders',
              hasPip: true,
              onClick: goToWorkOrders,
            },
          ]}
          columns={5}
          ariaLabel="Operations metrics"
        />

        {/* 4. Search & Actions Toolbar */}
        <div className="ops-toolbar">
          <label className="ops-search-box">
            <Icon name="search" size={20} />
            <input
              value={search}
              onChange={event => setSearch(event.target.value)}
              placeholder="Search visible reports, problems, and crews…"
              aria-label="Search visible reports and problems"
            />
          </label>
          <div className="ops-toolbar-actions">
            {(data.uncertainCount ?? 0) > 0 && (
              <button
                type="button"
                className="ops-refresh-btn"
                onClick={goToUncertainReports}
                title="Review uncertain citizen reports"
              >
                <Icon name="warning" size={16} />
                <span>Triage ({data.uncertainCount})</span>
              </button>
            )}
            <span className="ops-duty"><i /> On duty</span>
            <button
              type="button"
              className="ops-refresh-btn"
              onClick={() => setRefreshKey(key => key + 1)}
              aria-label="Refresh dashboard"
              title="Refresh dashboard"
            >
              <Icon name="refresh" size={16} />
              <span>Refresh</span>
            </button>
          </div>
        </div>

        <main className="ops-content">
          {data.errors.length > 0 && (
            <div className="ops-error" role="status">
              Could not load {data.errors.join(', ')}.{' '}
              <button type="button" onClick={() => setRefreshKey(key => key + 1)}>
                Try again
              </button>
            </div>
          )}
          <div className="ops-columns">
            <section className="ops-panel ops-priority">
              <div className="ops-panel-heading">
                <div className="ops-panel-title">
                  <span className="ops-red-dot" />
                  <h2>Critical &amp; high priority</h2>
                </div>
                <span className="ops-pill danger">{priorityProblems.length} shown</span>
              </div>
              <p className="ops-panel-description">Active hazards that need coordinator attention.</p>
              <div className="ops-stack">
                {shownProblems.map(problem => (
                  <article className="ops-problem-card" key={problem.id}>
                    <div className="ops-item-meta">
                      <span className={`ops-priority-tag ${problem.priority?.toLowerCase() === 'critical' ? 'critical' : ''}`}>
                        {label(problem.priority ?? 'High')} priority
                      </span>
                      <span>ID: {problem.id.slice(0, 8)}</span>
                    </div>
                    <h3>{problem.title}</h3>
                    <p>
                      <Icon name="location" size={16} /> {problem.address || 'Location unavailable'}
                    </p>
                    <div className="ops-card-footer">
                      <small>{problem.relatedReportCount} citizen reports linked</small>
                      <button type="button" onClick={() => navigate(`${ROUTES.PROBLEMS}?problemId=${problem.id}`)}>
                        Open Problems
                      </button>
                    </div>
                  </article>
                ))}
                {!loading && shownProblems.length === 0 && (
                  <p className="ops-empty">
                    {query ? 'No matching priority problems in this preview.' : 'No critical or high priority problems in this preview.'}
                  </p>
                )}
              </div>
              <button type="button" className="ops-panel-link" onClick={goToProblems}>
                Open Problems <Icon name="arrow-right" size={16} />
              </button>
            </section>
            <section className="ops-panel ops-reports">
              <div className="ops-panel-heading">
                <div className="ops-panel-title">
                  <Icon name="reports" size={24} />
                  <h2>Citizen reports</h2>
                </div>
                <small>Recent incoming</small>
              </div>
              <p className="ops-panel-description">Submissions awaiting review and processing.</p>
              <div className="ops-stack">
                {shownReports.map(report => (
                  <button type="button" className="ops-report-card" key={report.id} onClick={goToReports}>
                    <span className="ops-report-photo">
                      {report.firstPhotoUrl ? <img src={report.firstPhotoUrl} alt="" /> : <Icon name="reports" size={24} />}
                    </span>
                    <span className="ops-report-copy">
                      <span className="ops-report-meta">
                        <em>{label(report.category)}</em>
                        <small>{relativeTime(report.createdAt)}</small>
                      </span>
                      <strong>{report.description}</strong>
                      <small>{report.address || 'Location unavailable'}</small>
                      <span className="ops-report-status">{label(report.status)}</span>
                    </span>
                  </button>
                ))}
                {!loading && shownReports.length === 0 && (
                  <p className="ops-empty">
                    {query ? 'No matching recent reports.' : 'No recent reports to show.'}
                  </p>
                )}
              </div>
              <button type="button" className="ops-panel-link" onClick={goToReports}>
                Inspect all reports <Icon name="arrow-right" size={16} />
              </button>
            </section>
            <section className="ops-panel ops-ai">
              <div className="ops-panel-heading">
                <div className="ops-panel-title">
                  <Icon name="analytics" size={24} />
                  <h2>AI queue</h2>
                </div>
                <span className="ops-pill mint">Ready</span>
              </div>
              <p className="ops-panel-description">Field recommendations awaiting human approval.</p>
              <div className="ops-stack">
                {shownRecommendations.map(item => (
                  <article className="ops-ai-card" key={item.recommendationId}>
                    <div>
                      <span>{label(item.category)}</span>
                      <small>{label(item.priority)}</small>
                    </div>
                    <h3>{item.problemTitle}</h3>
                    <p>{item.recommendationReason}</p>
                    <small>Recommended crew: {item.recommendedCrewName || item.requiredCrewType || 'Unassigned'}</small>
                  </article>
                ))}
                {!loading && shownRecommendations.length === 0 && (
                  <p className="ops-empty">
                    {query ? 'No matching recommendations.' : 'No recommendations ready for review.'}
                  </p>
                )}
              </div>
              <button type="button" className="ops-primary-link" onClick={goToDispatch}>
                Recommendation review ({count(data.recommendationCount, loading)}) <Icon name="arrow-right" size={16} />
              </button>
            </section>
          </div>
        </main>
      </div>
    </div>
  );
}



