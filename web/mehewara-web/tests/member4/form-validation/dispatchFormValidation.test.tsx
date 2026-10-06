import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
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
  allowedActions: ['EDIT', 'REJECT', 'REGENERATE'],
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

describe('Dispatch Form Validation Tests (Member 4)', () => {
  it('Reject Recommendation Form disables the submit button until a reason is entered', () => {
    render(
      <RejectRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    const submitBtn = screen.getByRole('button', { name: 'Confirm Rejection' });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(true);

    const reasonField = screen.getByLabelText(/Reason for Rejection/);
    fireEvent.change(reasonField, { target: { value: '   ' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(true);

    fireEvent.change(reasonField, { target: { value: 'Crew reassigned to emergency ward' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(false);
  });

  it('Edit Recommendation Form keeps Save Overrides disabled until an edit reason is provided', async () => {
    const fetcher = vi.fn(async () => reply({ items: [] }));
    vi.stubGlobal('fetch', fetcher);

    render(
      <EditRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    await waitFor(() => expect(fetcher).toHaveBeenCalled());
    const submitBtn = screen.getByRole('button', { name: 'Save Overrides' });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(true);

    fireEvent.change(screen.getByLabelText(/Reason for this edit/), { target: { value: 'Escalated after second report' } });
    expect((submitBtn as HTMLButtonElement).disabled).toBe(false);
  });

  it('Edit Recommendation Form updates the priority tier and urgency score from user selection', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => reply({ items: [] })));

    render(
      <EditRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    expect(screen.getByRole('button', { name: 'HIGH' })).toHaveClass('active');

    fireEvent.click(screen.getByRole('button', { name: 'CRITICAL' }));
    expect(screen.getByRole('button', { name: 'CRITICAL' })).toHaveClass('active');
    expect(screen.getByRole('button', { name: 'HIGH' })).not.toHaveClass('active');

    const slider = screen.getByLabelText(/Priority Urgency Score/);
    fireEvent.change(slider, { target: { value: '95' } });
    expect(screen.getByText('95 / 100')).toBeInTheDocument();
  });

  it('Regenerate Recommendation Form requires feedback text before the request is submitted', () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);

    render(
      <RegenerateRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={vi.fn()} />
    );

    const feedback = screen.getByLabelText(/Reason and review feedback/) as HTMLTextAreaElement;
    expect(feedback.required).toBe(true);

    fireEvent.click(screen.getByRole('button', { name: 'Regenerate Assessment' }));
    expect(fetcher).not.toHaveBeenCalled();
  });
});
