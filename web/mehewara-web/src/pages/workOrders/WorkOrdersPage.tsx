import { useCallback, useEffect, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { WorkOrder, WorkOrderQuery } from '../../types/workOrders';
import type { PagedResult } from '../../types/problems';
import { ApiRequestError } from '../../services/api';
import { getWorkOrders, getWorkOrder, startWorkOrder, completeWorkOrder } from '../../services/workOrdersApi';
import { Header, HeroBanner, MetricsStrip } from '../../components/common';
import { OpsNavDrawer } from '../../components/common/OpsNavDrawer';
import { ROUTES } from '../../routes/paths';
import './WorkOrdersPage.css';

const date = (value: string | null) => value ? new Date(value).toLocaleString() : '—';
const label = (value?: string) => value ? value.replaceAll('_', ' ') : '';
const errorText = (error: unknown) => error instanceof Error ? error.message : 'Connection failed. Please retry.';

export function WorkOrdersPage({ user, token, initialId, onLogout, onProfile, onCoordinator, onNavigateToProblems, onNavigateToDispatch, onNavigateToCrews }: {
  user: User; token: string; initialId?: string; onLogout: () => void;
  onProfile: () => void; onCoordinator: () => void;
  onNavigateToProblems?: () => void;
  onNavigateToDispatch?: () => void;
  onNavigateToCrews?: () => void;
}) {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [isNavDrawerOpen, setIsNavDrawerOpen] = useState(false);

  const goToProblems = onNavigateToProblems || onCoordinator || (() => navigate(ROUTES.PROBLEMS));
  const goToDispatch = onNavigateToDispatch || (() => navigate(ROUTES.DISPATCH));
  const goToCrews = onNavigateToCrews || (() => navigate(ROUTES.CREWS));
  const goToProfile = onProfile || (() => navigate(ROUTES.PROFILE));

  const admin = user.role === 'ADMIN';
  const urlId = searchParams.get('id') || initialId;
  const urlCrewId = searchParams.get('crewId') || '';

  const [filters, setFilters] = useState<WorkOrderQuery>({ page: 1, pageSize: 20, crewId: urlCrewId || undefined });
  const [page, setPage] = useState<PagedResult<WorkOrder> | null>(null);
  const [selectedId, setSelectedId] = useState<string | undefined>(urlId);
  const [job, setJob] = useState<WorkOrder | null>(null);

  useEffect(() => {
    const idFromParam = searchParams.get('id');
    if (idFromParam && idFromParam !== selectedId) {
      setSelectedId(idFromParam);
    }
  }, [searchParams, selectedId]);

  const handleSelectJob = (id: string) => {
    if (id === selectedId) return;
    setJob(null);
    setNotes('');
    setMessage('');
    setSelectedId(id);
    try {
      const nextParams = new URLSearchParams(searchParams);
      nextParams.set('id', id);
      setSearchParams(Object.fromEntries(nextParams.entries()));
    } catch {
      // outside router fallback
    }
  };

  const [loading, setLoading] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState('');
  const [detailError, setDetailError] = useState('');
  const [message, setMessage] = useState('');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const listVersion = useRef(0);
  const detailVersion = useRef(0);
  const submitting = useRef(false);

  const loadList = useCallback(async () => {
    const version = ++listVersion.current;
    setLoading(true); setError('');
    try {
      const result = await getWorkOrders(token, admin, filters);
      if (version === listVersion.current) setPage(result);
    } catch (e) {
      if (version === listVersion.current) { setError(errorText(e)); setPage(null); }
    } finally { if (version === listVersion.current) setLoading(false); }
  }, [token, admin, filters]);

  const loadDetail = useCallback(async () => {
    const version = ++detailVersion.current;
    if (!selectedId) { setJob(null); return; }
    setDetailLoading(true); setDetailError('');
    try {
      const result = await getWorkOrder(token, selectedId);
      if (version === detailVersion.current) setJob(result);
    } catch (e) {
      if (version === detailVersion.current) { setDetailError(errorText(e)); setJob(null); }
    } finally { if (version === detailVersion.current) setDetailLoading(false); }
  }, [token, selectedId]);

  useEffect(() => { void loadList(); return () => { listVersion.current++; }; }, [loadList]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { void loadDetail(); return () => { detailVersion.current++; }; }, [loadDetail]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    const refresh = () => { if (!document.hidden && !submitting.current) { void loadList(); void loadDetail(); } };
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
    return () => { window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh); };
  }, [loadList, loadDetail]);

  async function transition(complete: boolean) {
    if (!job || submitting.current) return;
    submitting.current = true; setBusy(true); setMessage(''); setDetailError('');
    try {
      const updated = complete ? await completeWorkOrder(token, job.id, notes) : await startWorkOrder(token, job.id);
      setJob(updated); setNotes(''); setMessage(complete ? 'Job completed. Thank you.' : 'Job started.');
      await loadList();
    } catch (e) {
      if (e instanceof ApiRequestError && e.status === 409) {
        await Promise.all([loadList(), loadDetail()]);
        setMessage('This job changed since you opened it. The latest status has been loaded.');
      } else setDetailError(errorText(e));
    } finally { submitting.current = false; setBusy(false); }
  }

  function applyFilters(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    const from = String(values.get('from') || '');
    const to = String(values.get('to') || '');
    if (from && to && from > to) { setError('From date must be before the To date.'); return; }
    setSelectedId(undefined);
    setJob(null);
    setFilters({ page: 1, pageSize: 20, status: String(values.get('status') || ''),
      priority: String(values.get('priority') || ''), crewId: String(values.get('crewId') || '').trim(),
      problemId: String(values.get('problemId') || '').trim(),
      from: from ? new Date(`${from}T00:00:00`).toISOString() : undefined,
      to: to ? new Date(`${to}T23:59:59.999`).toISOString() : undefined });
  }

  return <div className="jobs-page">
    <main className="jobs-main">
      <Header
        currentUser={user}
        onLogout={onLogout}
        onOpenProfile={goToProfile}
        onBrandClick={goToProblems}
        roleBadgeText={admin ? "Municipal Coordinator" : "Crew Leader"}
        showName={true}
        showMenuButton={admin}
        onMenuClick={() => setIsNavDrawerOpen(prev => !prev)}
        isMenuOpen={isNavDrawerOpen}
      />
      {admin && (
        <OpsNavDrawer
          isOpen={isNavDrawerOpen}
          onClose={() => setIsNavDrawerOpen(false)}
          activePage="work-orders"
          onNavigateToDashboard={() => navigate(ROUTES.OPERATIONS)}
          onNavigateToProblems={goToProblems}
          onNavigateToDispatch={goToDispatch}
          onNavigateToCrews={goToCrews}
          onNavigateToWorkOrders={() => {}}
          onNavigateToReports={() => navigate(ROUTES.REPORTS)}
        />
      )}
      {!admin && (
        <div style={{ position: 'absolute', width: '1px', height: '1px', padding: 0, margin: '-1px', overflow: 'hidden', clip: 'rect(0, 0, 0, 0)', border: 0 }}>
          <button type="button" onClick={goToProfile}>My profile</button>
        </div>
      )}
      <HeroBanner
        badge={admin ? 'WORK ORDERS' : 'FIELD OPERATIONS'}
        title={admin ? 'Municipal Work Orders' : 'My Jobs'}
        subtitle={admin ? 'Track real-time crew job execution, site updates, completion evidence, and remediation telemetry across municipal units.' : 'Assigned field tasks, location details, remediation instructions, and completion notes for your municipal crew.'}
        ariaLabel={admin ? 'Municipal Work Orders Banner' : 'My Jobs Banner'}
      />
      {admin && (
        <MetricsStrip
          items={[
            {
              id: 'total',
              label: 'Total Orders',
              value: page?.totalItems ?? (page?.items?.length || 0),
              descriptor: 'Registered municipal work orders',
              hasPip: true,
            },
            {
              id: 'assigned',
              label: 'Assigned',
              value: page?.items?.filter(item => item.status === 'ASSIGNED').length || 0,
              descriptor: 'Awaiting crew kickoff',
            },
            {
              id: 'in-progress',
              label: 'In Progress',
              value: page?.items?.filter(item => item.status === 'IN_PROGRESS').length || 0,
              descriptor: 'Active field remediation',
            },
            {
              id: 'completed',
              label: 'Completed',
              value: page?.items?.filter(item => item.status === 'COMPLETED').length || 0,
              descriptor: 'Resolved and verified',
            },
          ]}
          ariaLabel="Municipal Work Orders Overview"
        />
      )}
      <form className="jobs-filters" onSubmit={applyFilters}>
        <label>Status<select name="status"><option value="">All jobs</option>{['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'].map(s => <option key={s} value={s}>{label(s)}</option>)}</select></label>
        <label>Priority<select name="priority"><option value="">All priorities</option>{['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map(s => <option key={s}>{s}</option>)}</select></label>
        {admin && <><label>Crew ID<input name="crewId" placeholder="All crews" pattern="[0-9a-fA-F-]{36}" /></label><label>Problem ID<input name="problemId" placeholder="All problems" pattern="[0-9a-fA-F-]{36}" /></label><label>Created from<input name="from" type="date" /></label><label>Created to<input name="to" type="date" /></label></>}
        <button className="jobs-primary" type="submit">Apply filters</button><button type="button" disabled={loading || busy} onClick={() => { void loadList(); void loadDetail(); }}>Refresh</button>
      </form>
      {error && <div className="jobs-error" role="alert">{error} <button onClick={() => void loadList()}>Retry</button></div>}
      <div className="jobs-grid"><section aria-label="Job list" aria-busy={loading}>
        <div className="jobs-section-heading"><h2>{admin ? 'Municipal jobs' : 'Your crew’s jobs'}</h2><span>{page?.totalItems ?? 0} jobs</span></div>
        {loading && <p role="status">Loading jobs…</p>}
        {!loading && (!page?.items || page.items.length === 0) && <div className="jobs-empty">No jobs match these filters.</div>}
        {page?.items?.map(item => <button className={`job-card ${item.id === selectedId ? 'selected' : ''}`} key={item.id} disabled={busy} onClick={() => handleSelectJob(item.id)}>
          <div className="job-tags"><span className={`job-priority priority-${item.priority?.toLowerCase()}`}>{item.priority}</span><span>{label(item.status)}</span></div>
          <h3>{item.title}</h3><p>{item.address || item.problemTitle}</p><footer><span>{item.crewName}</span><span>{date(item.assignedAt)}</span></footer>
        </button>)}
        <div className="jobs-pagination"><button disabled={loading || (filters.page || 1) <= 1} onClick={() => setFilters(f => ({ ...f, page: (f.page || 1) - 1 }))}>Previous</button><span>Page {filters.page} of {Math.max(1, page?.totalPages || 1)}</span><button disabled={loading || !page || (filters.page || 1) >= page.totalPages} onClick={() => setFilters(f => ({ ...f, page: (f.page || 1) + 1 }))}>Next</button></div>
      </section><section className="job-detail" aria-label="Job details" aria-busy={detailLoading}>
        {detailLoading && <p role="status">Loading job…</p>}
        {detailError && <div className="jobs-error" role="alert">{detailError} <button onClick={() => void loadDetail()}>Reload job</button></div>}
        {message && <div className="jobs-notice" role="status">{message}</div>}
        {!selectedId && <div className="jobs-empty"><h2>Select a job</h2><p>View its location, instructions, and progress here.</p></div>}
        {job && <><div className="job-tags"><span className={`job-priority priority-${job.priority?.toLowerCase()}`}>{job.priority}</span><span>{label(job.status)}</span></div><h2>{job.title}</h2><p>{job.crewName}</p>
          <h3>Location</h3><p>{job.address || 'Address unavailable'}<br /><small>{job.latitude}, {job.longitude}</small></p><a href={`https://www.google.com/maps/search/?api=1&query=${job.latitude},${job.longitude}`} target="_blank" rel="noreferrer">Open in Maps ↗</a>
          <h3>Instructions</h3><p className="job-notes">{job.instructions || 'No additional instructions.'}</p>
          <dl className="job-times"><dt>Assigned</dt><dd>{date(job.assignedAt)}</dd><dt>Started</dt><dd>{date(job.startedAt)}</dd><dt>Completed</dt><dd>{date(job.completedAt)}</dd></dl>
          {job.completionNotes && <><h3>Completion notes</h3><p className="job-notes">{job.completionNotes}</p></>}
          {!admin && job.status === 'ASSIGNED' && <button className="jobs-primary job-action" disabled={busy || detailLoading} onClick={() => void transition(false)}>{busy ? 'Starting…' : 'Start Job'}</button>}
          {!admin && job.status === 'IN_PROGRESS' && <form onSubmit={e => { e.preventDefault(); void transition(true); }}><label>Completion notes (optional)<textarea value={notes} maxLength={4000} rows={4} onChange={e => setNotes(e.target.value)} disabled={busy} placeholder="Describe the work completed…" /></label><small>{notes.length}/4000</small><button className="jobs-primary job-action" disabled={busy || detailLoading}>{busy ? 'Completing…' : 'Complete Job'}</button></form>}
          <h3>Activity history</h3>{(!job.history || job.history.length === 0) ? <p>No execution events recorded yet.</p> : <ol className="job-history">{job.history.map(a => <li key={a.id}><strong>{label(a.action)}</strong><time>{date(a.createdAt)}</time>{a.note && <p className="job-notes">{a.note}</p>}</li>)}</ol>}
          <small className="job-id">Job ID: {job.id}<br />Problem ID: {job.problemId}</small>
        </>}
      </section></div>
    </main>
  </div>;
}
