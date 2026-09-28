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
  try { const result = JSON.parse(value || '{}'); return `${result.status || 'NOT_RUN'}: ${(result.issues || []).join('; ')}`; }
  catch { return 'Historical validation unavailable.'; }
}

export function ValidationReviewPanel({ detail, token, onChange }: {
  detail: RecommendationDetail; token: string; onChange: (id?: string) => void;
}) {
  const [job, setJob] = useState<ReviewJob | null>(detail.latestJob);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const requestId = useRef<string | null>(null);
  const callback = useRef(onChange);
  callback.current = onChange;

  useEffect(() => { setJob(detail.latestJob); }, [detail.latestJob]);
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
          callback.current(current.resultRecommendationId || undefined);
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
      callback.current();
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to start validation.'); }
    finally { setSubmitting(false); }
  }

  return <div className="detail-section checklist-section">
    <h3>Validation and review</h3>
    <p>Revision {detail.revision} · {detail.isCurrent ? 'Current recommendation' : 'Superseded recommendation'}</p>
    <p>{detail.validation.status}</p>
    <ul>{detail.validation.issues.map((issue, i) => <li key={i}>{issue}</li>)}</ul>
    <ul>{detail.validation.checks?.map(check => <li key={check.code}>
      {check.passed ? 'Passed' : 'Failed'}: {check.message}
    </li>)}</ul>
    {detail.validation.findings?.map((finding, i) => <p key={i}>{finding.message}<br />
      Suggested correction: {finding.correction}<br />Evidence: {finding.evidenceRefs.join(', ')}</p>)}
    {job && <div role="status">
      <p>{job.kind === 'REGENERATE' ? 'Regeneration' : 'Validation'}: {job.status}</p>
      <p>Requested reason: {job.reason}</p>
      {job.error && <p role="alert">{job.error}</p>}
    </div>}
    {error && <p role="alert">{error}</p>}
    <button type="button" className="dispatch-btn-primary" onClick={validate}
      disabled={submitting || running || !detail.isCurrent || !!detail.reviewDecision || detail.requiresResponsibilityAcknowledgement === true}>
      {submitting ? 'Queuing validation…' : 'Validate current revision'}
    </button>
    <p>{detail.requiresResponsibilityAcknowledgement
      ? 'Human override: approval requires your responsibility acknowledgement and current backend business checks. Agent 4 is not rerun.'
      : 'AI recommendations require passing validation. Crew availability is checked again when you approve.'}</p>
    <details><summary>Recommendation history and changes</summary>
      {detail.history.map(item => <article key={item.recommendationId}>
        <h4>{item.recommendationId === detail.recommendationId ? 'Selected' : 'Earlier'} recommendation · revision {item.revision}</h4>
        <p>{new Date(item.createdAt).toLocaleString()}</p>
        <pre style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{historySummary(item.outputData)}</pre>
        <pre style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{validationSummary(item.validationResult)}</pre>
      </article>)}
      {detail.editHistory.map(edit => <article key={edit.id}>
        <h4>Coordinator edit ? {new Date(edit.createdAt).toLocaleString()}</h4><p>{edit.reason}</p>
        <p>Before</p><pre style={{ whiteSpace: 'pre-wrap' }}>{historySummary(edit.before)}</pre>
        <p>After</p><pre style={{ whiteSpace: 'pre-wrap' }}>{historySummary(edit.after)}</pre>
      </article>)}
      {detail.validationHistory.map(attempt => <p key={attempt.id}>
        {new Date(attempt.startedAt).toLocaleString()} ? {validationSummary(attempt.result)}
      </p>)}
    </details>
  </div>;
}
