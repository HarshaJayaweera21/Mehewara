import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { MemoryRouter } from 'react-router-dom';
import { DispatchDashboardPage } from '../../src/pages/dispatch/DispatchDashboardPage';
import type { RecommendationListItem, RecommendationDetail } from '../../src/types/dispatch';
import type { CrewAvailabilityItem } from '../../src/types/crew';

const mockRecItem: RecommendationListItem = {
  recommendationId: 'rec-001',
  revision: 1,
  isCurrent: true,
  problemId: 'prob-001',
  problemTitle: 'Flooded Underpass in Borella',
  address: 'Borella Junction, Colombo 08',
  category: 'DRAINAGE',
  priority: 'CRITICAL',
  priorityScore: 92,
  priorityReasons: ['Critical arterial route with severe public transit obstruction.'],
  requiredCrewType: 'DRAINAGE',
  recommendedCrewId: 'crew-001',
  recommendedCrewName: 'Drainage Unit Alpha',
  recommendationReason: 'Critical arterial route with severe public transit obstruction.',
  dispatchStrategy: 'URGENT_CRITICAL_PRIORITY',
  reviewDecision: null,
  reviewBucket: 'READY',
  reviewProgress: 'READY_FOR_REVIEW',
  attentionReason: null,
  allowedActions: ['APPROVE', 'EDIT', 'REJECT', 'REGENERATE'],
  canApprove: true,
  previousRecommendationId: null,
  latestJob: null,
  validation: {
    status: 'VALID',
    issues: [],
    checks: [
      { code: 'VERIFIED_REPORT', passed: true, message: 'Report is officially verified' },
      { code: 'CAPABILITY_MATCH', passed: true, message: 'Squad possesses drainage pumps' },
    ],
  },
  createdAt: '2026-10-05T08:00:00Z',
};

const mockRecDetail: RecommendationDetail = {
  ...mockRecItem,
  latitude: 6.915,
  longitude: 79.872,
  address: 'Borella Junction, Colombo 08',
  problemDescription: 'Drainage blockage on main avenue',
  reportCount: 1,
  reportDescriptions: ['Flooded street'],
  recommendedCrewStatus: 'AVAILABLE',
  reviewReason: null,
  reviewedBy: null,
  reviewedAt: null,
  workOrderId: null,
  history: [],
  editHistory: [],
  validationHistory: [],
  jobHistory: [],
};

const mockCrews: CrewAvailabilityItem[] = [
  {
    id: 'crew-001',
    name: 'Drainage Unit Alpha',
    crewType: 'DRAINAGE',
    status: 'AVAILABLE',
    activeWorkOrderId: null,
  },
];

const mockUser = {
  id: 'coord-1',
  name: 'Coordinator Silva',
  email: 'silva@colombo.gov.lk',
  role: 'COORDINATOR',
};

const reply = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('DispatchDashboardPage Tests (Member 3)', () => {
  it('renders queue and loads recommendations and telemetry', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/dispatch/recommendations/rec-001')) {
        return reply(mockRecDetail);
      }
      if (url.includes('/api/dispatch/recommendations')) {
        return reply({
          items: [mockRecItem],
          totalItems: 1,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      if (url.includes('/api/crews/availability')) {
        return reply({ items: mockCrews });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <DispatchDashboardPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    // Verify recommendations list item appears
    expect((await screen.findAllByText('Flooded Underpass in Borella')).length).toBeGreaterThan(0);
    expect(screen.getAllByText('Drainage Unit Alpha').length).toBeGreaterThan(0);

    // Verify review bucket tabs render
    expect(screen.getByText('Ready for Approval')).toBeInTheDocument();
    expect(screen.getByText('Processing')).toBeInTheDocument();
  });

  it('selects a recommendation and renders the validation review panel', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/dispatch/recommendations/rec-001')) {
        return reply(mockRecDetail);
      }
      if (url.includes('/api/dispatch/recommendations')) {
        return reply({
          items: [mockRecItem],
          totalItems: 1,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      if (url.includes('/api/crews/availability')) {
        return reply({ items: mockCrews });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <DispatchDashboardPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    const itemCards = await screen.findAllByText('Flooded Underpass in Borella');
    fireEvent.click(itemCards[0]);

    // Verify detail panel actions are rendered
    expect(await screen.findByRole('button', { name: /Approve & Dispatch/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Edit/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Reject/i })).toBeInTheDocument();
  }, 15000);

  it('filters recommendations by priority', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/dispatch/recommendations')) {
        return reply({
          items: [mockRecItem],
          totalItems: 1,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      if (url.includes('/api/crews/availability')) {
        return reply({ items: mockCrews });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <DispatchDashboardPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    await screen.findAllByText('Flooded Underpass in Borella');

    // Change Priority select filter
    const prioritySelect = screen.getByLabelText('Filter by Priority');
    fireEvent.change(prioritySelect, { target: { value: 'CRITICAL' } });

    await waitFor(() => {
      expect(
        fetcher.mock.calls.some(([url]) => (url as string).includes('priority=CRITICAL'))
      ).toBe(true);
    });
  });

  it('opens Approve modal upon clicking Approve & Dispatch button', async () => {
    const fetcher = vi.fn(async (url: string) => {
      if (url.includes('/api/dispatch/recommendations/rec-001')) {
        return reply(mockRecDetail);
      }
      if (url.includes('/api/dispatch/recommendations')) {
        return reply({
          items: [mockRecItem],
          totalItems: 1,
          totalPages: 1,
          page: 1,
          pageSize: 20,
        });
      }
      if (url.includes('/api/crews/availability')) {
        return reply({ items: mockCrews });
      }
      return reply({});
    });
    vi.stubGlobal('fetch', fetcher);

    render(
      <MemoryRouter>
        <DispatchDashboardPage currentUser={mockUser} token="mock-coord-token" />
      </MemoryRouter>
    );

    const itemCards = await screen.findAllByText('Flooded Underpass in Borella');
    fireEvent.click(itemCards[0]);

    const approveBtn = await screen.findByRole('button', { name: /Approve & Dispatch/i });
    fireEvent.click(approveBtn);

    // Verify modal appears
    expect(await screen.findByText('Authorize Municipal Work Order')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Confirm & Issue Work Order/i })).toBeInTheDocument();
  }, 15000);
});
