import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { ApproveRecommendationModal } from '../../../src/pages/dispatch/components/ApproveRecommendationModal';
import { RejectRecommendationModal } from '../../../src/pages/dispatch/components/RejectRecommendationModal';
import { EditRecommendationModal } from '../../../src/pages/dispatch/components/EditRecommendationModal';
import { RegenerateRecommendationModal } from '../../../src/pages/dispatch/components/RegenerateRecommendationModal';
import type { RecommendationListItem } from '../../../src/types/dispatch';

const baseRecommendation: RecommendationListItem = {
  recommendationId: 'rec-1',
  revision: 1,
  isCurrent: true,
  currentRecommendationId: null,
  reviewBucket: 'READY',
  reviewProgress: 'PENDING',
  attentionReason: null,
  allowedActions: ['APPROVE', 'EDIT', 'REJECT', 'REGENERATE'],
  canApprove: true,
  origin: null,
  editedBy: null,
  editedAt: null,
  requiresResponsibilityAcknowledgement: false,
  previousRecommendationId: null,
  latestJob: null,
  problemId: 'problem-1',
  problemTitle: 'Pothole on Main St',
  address: 'Main St',
  category: 'ROAD',
  priority: 'HIGH',
  priorityScore: 70,
  priorityReasons: ['Blocks traffic near a school'],
  requiredCrewType: 'ROAD',
  recommendedCrewId: 'crew-1',
  recommendedCrewName: 'Road Crew Alpha',
  recommendationReason: 'Road crew needed urgently',
  dispatchStrategy: 'STANDARD_DISPATCH',
  estimatedDurationMinutes: 90,
  distanceKm: 2.5,
  estimatedTravelMinutes: 15,
};

const reply = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });

beforeEach(() => {
  localStorage.setItem('mehewara_token', 'token');
});

afterEach(() => {
  vi.unstubAllGlobals();
  localStorage.clear();
});

describe('ApproveRecommendationModal', () => {
  it('submits an approval without a reason and reports the created work order id', async () => {
    const fetcher = vi.fn(async () => reply({ workOrder: { id: 'wo-123' } }));
    vi.stubGlobal('fetch', fetcher);
    const onSuccess = vi.fn();
    render(
      <ApproveRecommendationModal
        recommendation={baseRecommendation}
        token="token"
        onClose={vi.fn()}
        onSuccess={onSuccess}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: /Confirm & Issue Work Order/ }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledWith('wo-123'));
    const [url, options] = fetcher.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('/dispatch/recommendations/rec-1/approve');
    expect(JSON.parse(options.body as string)).toEqual({
      reason: undefined,
      expectedRevision: 1,
      acknowledgeHumanOverrideResponsibility: false,
    });
  });

  it('requires a reason and the responsibility checkbox for a human override recommendation', async () => {
    const humanOverrideRec = { ...baseRecommendation, requiresResponsibilityAcknowledgement: true };
    render(
      <ApproveRecommendationModal
        recommendation={humanOverrideRec}
        token="token"
        onClose={vi.fn()}
        onSuccess={vi.fn()}
      />
    );

    const submit = screen.getByRole('button', { name: /Confirm & Issue Work Order/ });
    expect(submit).toBeDisabled();

    fireEvent.change(screen.getByLabelText(/Approval reason/), { target: { value: 'Reviewed the override manually' } });
    expect(submit).toBeDisabled();

    fireEvent.click(screen.getByRole('checkbox'));
    expect(submit).not.toBeDisabled();
  });

  it('shows a server error message and keeps the modal open on failure', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => reply({ error: { code: 'CONFLICT', message: 'Recommendation already decided' } }, 409)));
    render(
      <ApproveRecommendationModal
        recommendation={baseRecommendation}
        token="token"
        onClose={vi.fn()}
        onSuccess={vi.fn()}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: /Confirm & Issue Work Order/ }));

    expect(await screen.findByText(/Recommendation already decided|Approval failed/)).toBeInTheDocument();
  });

  it('calls onClose when the backdrop is clicked but not when the card is clicked', () => {
    const onClose = vi.fn();
    const { container } = render(
      <ApproveRecommendationModal
        recommendation={baseRecommendation}
        token="token"
        onClose={onClose}
        onSuccess={vi.fn()}
      />
    );

    fireEvent.click(screen.getByText('Authorize Municipal Work Order'));
    expect(onClose).not.toHaveBeenCalled();

    fireEvent.click(container.querySelector('.dispatch-modal-backdrop')!);
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});

describe('RejectRecommendationModal', () => {
  it('blocks submission and shows a validation message when no reason is entered', () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);
    render(
      <RejectRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    expect(screen.getByRole('button', { name: 'Confirm Rejection' })).toBeDisabled();
    fireEvent.submit(screen.getByRole('button', { name: 'Confirm Rejection' }).closest('form')!);

    expect(fetcher).not.toHaveBeenCalled();
  });

  it('submits the rejection reason and the expected revision for optimistic concurrency', async () => {
    const fetcher = vi.fn(async () => reply({ success: true }));
    vi.stubGlobal('fetch', fetcher);
    const onSuccess = vi.fn();
    render(
      <RejectRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={onSuccess} />
    );

    fireEvent.change(screen.getByLabelText(/Reason for Rejection/), {
      target: { value: 'Crew reassigned to emergency ward' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Confirm Rejection' }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledTimes(1));
    const [url, options] = fetcher.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('/dispatch/recommendations/rec-1/reject');
    expect(JSON.parse(options.body as string)).toEqual({
      reason: 'Crew reassigned to emergency ward',
      expectedRevision: 1,
    });
  });
});

describe('EditRecommendationModal', () => {
  it('loads available crews and requires an edit reason before saving overrides', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/crews')) {
        return reply({ items: [{ id: 'crew-2', name: 'Drainage Crew', crewType: 'DRAINAGE', status: 'AVAILABLE' }] });
      }
      return reply({ ...baseRecommendation, priority: 'CRITICAL' });
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <EditRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    await screen.findByText(/Drainage Crew/);
    expect(screen.getByRole('button', { name: 'Save Overrides' })).toBeDisabled();

    fireEvent.change(screen.getByLabelText(/Reason for this edit/), { target: { value: 'Site visit confirmed severity' } });
    expect(screen.getByRole('button', { name: 'Save Overrides' })).not.toBeDisabled();
  });

  it('submits the edit payload with the selected priority tier and expected revision', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/crews')) return reply({ items: [] });
      return reply({ ...baseRecommendation, priority: 'CRITICAL' });
    });
    vi.stubGlobal('fetch', fetcher);
    const onSuccess = vi.fn();

    render(
      <EditRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={onSuccess} />
    );

    await waitFor(() => expect(fetcher).toHaveBeenCalled());
    fireEvent.click(screen.getByRole('button', { name: 'CRITICAL' }));
    fireEvent.change(screen.getByLabelText(/Reason for this edit/), { target: { value: 'Escalated after second report' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save Overrides' }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledTimes(1));
    const editCall = fetcher.mock.calls.find(([url]) => (url as string).includes('/dispatch/recommendations/rec-1'));
    const [, options] = editCall as [string, RequestInit];
    const body = JSON.parse(options.body as string);
    expect(body.priority).toBe('CRITICAL');
    expect(body.editReason).toBe('Escalated after second report');
    expect(body.expectedRevision).toBe(1);
  });
});

describe('RegenerateRecommendationModal', () => {
  it('renders the current priority and crew summary for the coordinator to review', () => {
    render(
      <RegenerateRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    expect(screen.getByText('Pothole on Main St')).toBeInTheDocument();
    expect(screen.getByText(/HIGH \(70\/100\)/)).toBeInTheDocument();
    expect(screen.getByText('Road Crew Alpha')).toBeInTheDocument();
  });

  it('submits feedback with a generated request id and the expected revision', async () => {
    const fetcher = vi.fn(async () => reply({ jobId: 'job-1', status: 'QUEUED', statusUrl: '/dispatch/review-jobs/job-1' }));
    vi.stubGlobal('fetch', fetcher);
    const onSuccess = vi.fn();

    render(
      <RegenerateRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={onSuccess} />
    );

    fireEvent.change(screen.getByLabelText(/Reason and review feedback/), { target: { value: 'Crew went unavailable, reassign' } });
    fireEvent.click(screen.getByRole('button', { name: 'Regenerate Assessment' }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledTimes(1));
    const [url, options] = fetcher.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('/dispatch/recommendations/rec-1/regenerate');
    const body = JSON.parse(options.body as string);
    expect(body.reason).toBe('Crew went unavailable, reassign');
    expect(body.expectedRevision).toBe(1);
    expect(typeof body.requestId).toBe('string');
    expect(body.requestId.length).toBeGreaterThan(0);
  });
});
