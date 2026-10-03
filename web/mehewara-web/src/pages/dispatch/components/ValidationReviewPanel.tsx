import { useEffect, useRef, useState } from 'react';
import type { RecommendationDetail, ReviewJob } from '../../../types/dispatch';
import { getReviewJob, validateRecommendation } from '../../../services/dispatchApi';

function historySummary(value: string | null) {
  try {
    const rec = JSON.parse(value || '{}');
    return `${rec.priority || 'Unknown priority'} (${rec.priorityScore ?? '?'}/100) ? ${rec.requiredCrewType || 'Unknown specialty'}\nCrew: ${rec.recommendedCrewName || rec.recommendedCrewId || 'None'}\n${(rec.priorityReasons || []).join('\n')}\n${rec.recommendationReason || ''}`;
  } catch { return 'Historical recommendation could not be displayed.'; }
}
function validationSummary(value: string | null) {
  try { const result = JSON.parse(value || '{}'); return `${result.status || 'NOT_RUN'}${result.recommendationRevision ? ` · revision ${result.recommendationRevision}` : ''}: ${(result.issues || []).join('; ')}`; }
  catch { return 'Historical validation unavailable.'; }
}

export function ValidationReviewPanel({ detail, token, onChange }: {
  detail: RecommendationDetail; token: string; onChange: (id?: string, bucket?: string) => void;
}) {
  const [job, setJob] = useState<ReviewJob | null>(detail.latestJob);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const requestId = useRef<string | null>(null);
  const callback = useRef(onChange);
  useEffect(() => { callback.current = onChange; });

  useEffect(() => { setJob(detail.latestJob); setNow(Date.now()); }, [detail.latestJob]);
  useEffect(() => { requestId.current = null; }, [detail.recommendationId, detail.revision]);
  const jobId = job?.id;
  const running = job?.status === 'QUEUED' || job?.status === 'RUNNING';
  useEffect(() => {
    if (!jobId || !running) return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    async function poll() {
      try {
        const current = await getReviewJob(token, jobId!);
        if (cancelled) return;
        setError(''); setJob(current);
        if (current.status === 'COMPLETED' || current.status === 'FAILED') {
          requestId.current = null;
          // A failed candidate may be an audit-only result. Refresh authoritative
          // current recommendation/child state instead of selecting that candidate.
          callback.current();
          return;
        }
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : 'Unable to refresh review progress.');
      }
      timer = setTimeout(poll, 2500);
    }
    timer = setTimeout(poll, 1000);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [jobId, running, token]);

  async function validate() {
    setSubmitting(true); setError('');
    requestId.current ??= crypto.randomUUID();
    try {
      const accepted = await validateRecommendation(token, detail.recommendationId, {
        reason: 'Coordinator requested validation of the current revision.',
        expectedRevision: detail.revision, requestId: requestId.current,
      });
      setJob(await getReviewJob(token, accepted.jobId));
      callback.current(undefined, 'PROCESSING');
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to start validation.'); }
    finally { setSubmitting(false); }
  }

  return <div className="detail-section checklist-section">
    <h3>Validation and review</h3>
    <p><strong>{detail.reviewProgress.replace(/_/g, ' ')}</strong> · {detail.origin?.replace(/_/g, ' ') || 'Legacy / unknown origin'}</p>
    {detail.attentionReason && <p role="status">{detail.attentionReason}</p>}
    {detail.editedBy && <p>Edited by {detail.editedBy} {detail.editedAt && `on ${new Date(detail.editedAt).toLocaleString()}`}</p>}
    {!detail.isCurrent && detail.currentRecommendationId && <button type="button"
      onClick={() => callback.current(detail.currentRecommendationId!)}>View current recommendation</button>}
    <p>Revision {detail.revision} · {detail.isCurrent ? 'Current recommendation' : 'Superseded recommendation'}</p>
    <p>{detail.validation.status}</p>
    {detail.validation.suggestedAction && <p>Suggested action: {detail.validation.suggestedAction.replace(/_/g, ' ')}. This is guidance; it does not dispatch work.</p>}
    {detail.validation.snapshotAt && <p>Evidence reviewed: {new Date(detail.validation.snapshotAt).toLocaleString()}</p>}
    {detail.validation.evidenceRefs?.length ? <p>Evidence: {detail.validation.evidenceRefs.join(', ')}</p> : null}
    {detail.validation.snapshotHash && <details><summary>Evidence snapshot fingerprint</summary><code className="review-fingerprint">{detail.validation.snapshotHash}</code></details>}
    <ul>{detail.validation.issues.map((issue, i) => <li key={i}>{issue}</li>)}</ul>
    <ul>{detail.validation.checks?.map(check => <li key={check.code}>
      {check.passed ? 'Passed' : 'Failed'}: {check.message}
    </li>)}</ul>
    {detail.validation.findings?.map((finding, i) => <p key={i}>{finding.message}<br />
      Suggested correction: {finding.correction}<br />Evidence: {finding.evidenceRefs.join(', ')}</p>)}
    {job && <div role="status">
      <p>{job.kind === 'REGENERATE' ? 'Regeneration' : 'Validation'}: {job.status}</p>
      {job.recommendationId !== detail.recommendationId && <p>This workflow job targets another recommendation: {job.recommendationId}.</p>}
      <p>Requested reason: {job.reason}</p>
      <p>Execution attempts: {job.attempts} / 3 · Automatic corrections: {job.correctionCount ?? 'Unknown'} / 2 · Evidence revalidations: {job.evidenceRetryCount ?? 'Unknown'} / 2</p>
      {job.status === 'QUEUED' && job.nextAttemptAt && new Date(job.nextAttemptAt).getTime() > now &&
        <p>Scheduled retry: {new Date(job.nextAttemptAt).toLocaleString()}</p>}
      {job.error && <p role="alert">{job.error}</p>}
    </div>}
    {error && <p role="alert">{error}</p>}
    <button type="button" className="dispatch-btn-primary" onClick={validate}
      disabled={submitting || running || !detail.allowedActions.includes('VALIDATE')}>
      {submitting ? 'Queuing validation…' : ['ERROR', 'INVALID', 'NOT_RUN', 'REVISION_REQUIRED'].includes(detail.validation.status) ? 'Retry Agent 4 validation' : 'Validate current revision'}
    </button>
    <p>{detail.requiresResponsibilityAcknowledgement
      ? 'Human override: approval requires your responsibility acknowledgement and current backend business checks. Agent 4 is not rerun.'
      : 'AI recommendations require passing validation. Crew availability is checked again when you approve.'}</p>
    <details><summary>Recommendation history and changes</summary>
      {detail.originalOutputData && <details><summary>Original AI output for this recommendation</summary>
        <pre className="review-history-text">{historySummary(detail.originalOutputData)}</pre></details>}
      {detail.history.map(item => <article key={item.recommendationId}>
        <h4>{item.recommendationId === detail.currentRecommendationId ? 'Current' : item.recommendationId === detail.recommendationId ? 'Selected historical' : 'Historical / attempted'} recommendation · revision {item.revision}</h4>
        {item.recommendationId !== detail.recommendationId && <button type="button" onClick={() => callback.current(item.recommendationId)}>View recommendation</button>}
        {item.previousRecommendationId && <p>Predecessor: {item.previousRecommendationId}</p>}
        <p>{new Date(item.createdAt).toLocaleString()}</p>
        <pre style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{historySummary(item.outputData)}</pre>
        <pre style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{validationSummary(item.validationResult)}</pre>
      </article>)}
      {detail.editHistory.map(edit => <article key={edit.id}>
        <h4>Coordinator edit · {new Date(edit.createdAt).toLocaleString()}</h4><p>Editor: {edit.actorUserId}</p><p>{edit.reason}</p>
        <p>Before</p><pre style={{ whiteSpace: 'pre-wrap' }}>{historySummary(edit.before)}</pre>
        <p>After</p><pre style={{ whiteSpace: 'pre-wrap' }}>{historySummary(edit.after)}</pre>
      </article>)}
      {detail.validationHistory.map(attempt => <p key={attempt.id}>
        {new Date(attempt.startedAt).toLocaleString()} ? {validationSummary(attempt.result)}
      </p>)}
    </details>
    <details><summary>Correction and retry jobs ({detail.jobHistory.length})</summary>
      {detail.jobHistory.map(item => <article key={item.id} className="review-job-history">
        <h4>{item.kind} · {item.status}</h4>
        <p>{new Date(item.createdAt).toLocaleString()} · Recommendation revision {item.expectedRevision}</p>
        <p>{item.reason}</p><p>Attempts: {item.attempts}; corrections: {item.correctionCount ?? 'Unknown'}; evidence retries: {item.evidenceRetryCount ?? 'Unknown'}</p>
        <p>Initiated by: {item.requestedBy} · {item.origin || 'Legacy / unknown origin'}</p>
        <p>Chain: {item.chainId || 'Legacy / unknown'} · Parent: {item.parentJobId || 'None'}</p>
        {item.error && <p>{item.error}</p>}
      </article>)}
    </details>
    {detail.humanOverrideApproval && <details><summary>Human responsibility acknowledgement</summary>
      <p>Revision {detail.humanOverrideApproval.revision} approved by {detail.humanOverrideApproval.acknowledgedBy} on {new Date(detail.humanOverrideApproval.acknowledgedAt).toLocaleString()}</p>
      <p>{detail.humanOverrideApproval.reason}</p><p>WorkOrder: {detail.humanOverrideApproval.workOrderId}</p>
    </details>}
  </div>;
}
