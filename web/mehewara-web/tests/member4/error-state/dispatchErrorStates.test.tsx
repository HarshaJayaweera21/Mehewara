import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { getRecommendations, approveRecommendation } from '../../../src/services/dispatchApi';
import { ApproveRecommendationModal } from '../../../src/pages/dispatch/components/ApproveRecommendationModal';
import { DispatchDashboardPage } from '../../../src/pages/dispatch/DispatchDashboardPage';
import * as dispatchApi from '../../../src/services/dispatchApi';
import * as crewApi from '../../../src/services/crewApi';
import type { RecommendationListItem } from '../../../src/types/dispatch';

vi.mock('../../../src/components/common', async (importOriginal) => {
  const actual = await importOriginal<Record<string, unknown>>();
  return {
    ...actual,
    Header: () => <div data-testid="mock-header">Header</div>,
  };
});

const baseRecommendation: RecommendationListItem = {
  recommendationId: 'rec-1',
  revision: 1,
  isCurrent: true,
  currentRecommendationId: null,
  reviewBucket: 'READY',
  reviewProgress: 'PENDING',
  attentionReason: null,
  allowedActions: ['APPROVE'],
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
  validation: { status: 'VALID', issues: [] },
  reviewDecision: null,
  createdAt: '2026-10-01T00:00:00Z',
};

describe('Dispatch Error States Tests (Member 4)', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
    localStorage.setItem('mehewara_token', 'valid-token');
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('handleResponse surfaces a stale-revision 409 conflict from approveRecommendation', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 409,
      json: async () => ({ error: { code: 'STALE_REVISION', message: 'Recommendation has changed since it was loaded.' } }),
    } as unknown as Response);

    await expect(approveRecommendation('token', 'rec-1', { expectedRevision: 1 })).rejects.toThrow(
      'Recommendation has changed since it was loaded.'
    );
  });

  it('ApproveRecommendationModal renders the server error and keeps the modal open on a failed approval', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 409,
      json: async () => ({ error: { code: 'STALE_REVISION', message: 'Recommendation has changed since it was loaded.' } }),
    } as unknown as Response);

    const onSuccess = vi.fn();
    render(
      <ApproveRecommendationModal recommendation={baseRecommendation} token="token" onClose={vi.fn()} onSuccess={onSuccess} />
    );

    fireEvent.click(screen.getByRole('button', { name: /Confirm & Issue Work Order/ }));

    expect(await screen.findByText('Recommendation has changed since it was loaded.')).toBeInTheDocument();
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('handleResponse falls back to a status error string when the dispatch API response is not JSON', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error('Not JSON');
      },
    } as unknown as Response);

    await expect(getRecommendations('token')).rejects.toThrow('Request failed with status 500');
  });

  it('DispatchDashboardPage displays an error banner when the recommendation queue fails to load', async () => {
    vi.spyOn(dispatchApi, 'getRecommendations').mockRejectedValue(
      new Error('Unable to connect to dispatch recommendation engine.')
    );
    vi.spyOn(crewApi, 'getCrewAvailability').mockResolvedValue({ items: [] });

    render(
      <MemoryRouter>
        <DispatchDashboardPage token="valid-token" />
      </MemoryRouter>
    );

    expect(await screen.findByText('Unable to connect to dispatch recommendation engine.')).toBeInTheDocument();
  });

  it('DispatchDashboardPage retries the queue fetch when the Refresh control is used', async () => {
    const getRecsSpy = vi
      .spyOn(dispatchApi, 'getRecommendations')
      .mockResolvedValueOnce({ items: [], totalItems: 0, page: 1, pageSize: 20, totalPages: 1 })
      .mockResolvedValueOnce({ items: [], totalItems: 0, page: 1, pageSize: 20, totalPages: 1 });
    vi.spyOn(crewApi, 'getCrewAvailability').mockResolvedValue({ items: [] });

    render(
      <MemoryRouter>
        <DispatchDashboardPage token="valid-token" />
      </MemoryRouter>
    );

    await waitFor(() => expect(getRecsSpy).toHaveBeenCalledTimes(1));
    fireEvent.click(screen.getByRole('button', { name: /Refresh/ }));
    await waitFor(() => expect(getRecsSpy).toHaveBeenCalledTimes(2));
  });
});
