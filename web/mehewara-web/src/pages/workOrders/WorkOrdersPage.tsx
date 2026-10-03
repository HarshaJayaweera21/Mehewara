import { useCallback, useEffect, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import type { User } from '../../types/auth';
import type { WorkOrder, WorkOrderQuery } from '../../types/workOrders';
import type { PagedResult } from '../../types/problems';
import { ApiRequestError } from '../../services/api';
import { getWorkOrders, getWorkOrder, startWorkOrder, completeWorkOrder } from '../../services/workOrdersApi';
import { Header } from '../../components/common';
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
  let navigate: (to: string) => void = () => {};
  let searchParams: URLSearchParams = new URLSearchParams();
  let setSearchParams: (params: Record<string, string>) => void = () => {};
  try {
    navigate = useNavigate();
    const [sp, setSp] = useSearchParams();
    searchParams = sp;
    setSearchParams = setSp;
  } catch {
    // Tests outside router
  }

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
  }, [searchParams]);

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
    <Header
      currentUser={user}
      onLogout={onLogout}
      onOpenProfile={goToProfile}
      onBrandClick={goToProblems}
      roleBadgeText={admin ? "Municipal Coordinator" : "Crew Leader"}
    />
    <main className="jobs-main">
      {!admin && (
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '-0.5rem' }}>
          <button type="button" onClick={goToProfile} style={{ fontSize: '0.85rem' }}>My profile</button>
        </div>
      )}
      {admin && (
        <nav className="operations-nav-strip" aria-label="Operations Navigation">
          <div className="nav-strip-left">
            <button type="button" className="nav-strip-btn" onClick={goToProblems}>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
              <span>Problems Board</span>
            </button>
            <span className="nav-strip-divider">/</span>
            <button type="button" className="nav-strip-btn" onClick={goToDispatch}>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polygon points="12 2 2 7 12 12 22 7 12 2" />
                <polyline points="2 17 12 22 22 17" />
                <polyline points="2 12 12 17 22 12" />
              </svg>
              <span>Dispatch Queue (Agent 3)</span>
            </button>
            <span className="nav-strip-divider">/</span>
            <button type="button" className="nav-strip-btn" onClick={goToCrews}>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
              <span>Municipal Crews</span>
            </button>
            <span className="nav-strip-divider">/</span>
            <button type="button" className="nav-strip-btn active" aria-current="page">
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
        </nav>
      )}
      <div className="jobs-welcome-banner">
        <h1 className="jobs-banner-heading">{admin ? 'Municipal Work Orders' : 'My Jobs'}</h1>
        <p className="jobs-banner-sub">{admin ? 'Monitor real-time crew job execution, completion notes, and location telemetry across all municipal units.' : `Welcome back, ${user.firstName || user.name}. View assigned maintenance tasks and submit execution completion notes.`}</p>
      </div>
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
