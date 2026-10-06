import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { ApproveRecommendationModal } from '../../src/pages/dispatch/components/ApproveRecommendationModal';
import { RejectRecommendationModal } from '../../src/pages/dispatch/components/RejectRecommendationModal';
import { EditRecommendationModal } from '../../src/pages/dispatch/components/EditRecommendationModal';
import { RegenerateRecommendationModal } from '../../src/pages/dispatch/components/RegenerateRecommendationModal';
import type { RecommendationListItem, RecommendationDetail } from '../../src/types/dispatch';

const baseRec: RecommendationListItem = {
  recommendationId: 'rec-001',
  problemId: 'prob-001',
  problemTitle: 'Flooded Culvert',
  category: 'DRAINAGE',
  priority: 'HIGH',
  priorityScore: 88,
  recommendedCrewId: 'crew-001',
  recommendedCrewName: 'Drainage Squad Alpha',
  requiredCrewType: 'DRAINAGE',
  recommendationReason: 'Critical flood risk',
  priorityReasons: ['Near hospital', 'High traffic'],
  reviewDecision: null,
  reviewBucket: 'READY',
  reviewProgress: 'READY_FOR_REVIEW',
  attentionReason: null,
  allowedActions: ['APPROVE', 'EDIT', 'REJECT', 'REGENERATE'],
  canApprove: true,
  isCurrent: true,
  previousRecommendationId: null,
  latestJob: null,
  revision: 1,
  validation: {
    status: 'VALID',
    issues: [],
    checks: [],
  },
  createdAt: '2026-10-05T08:00:00Z',
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

describe('Dispatch Modals Action Tests (Member 3)', () => {
  describe('ApproveRecommendationModal', () => {
    it('submits coordinator approval and triggers onSuccess callback', async () => {
      const onSuccess = vi.fn();
      const onClose = vi.fn();
      const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
        if (url.includes('/approve')) {
          const body = JSON.parse(options?.body as string);
          expect(body.expectedRevision).toBe(1);
          return reply({
            recommendation: { ...baseRec, reviewDecision: 'APPROVED' },
            workOrder: { id: 'wo-123', problemId: 'prob-001' },
          });
        }
        return reply({});
      });
      vi.stubGlobal('fetch', fetcher);

      render(
        <ApproveRecommendationModal
          recommendation={baseRec}
          token="mock-token"
          onClose={onClose}
          onSuccess={onSuccess}
        />
      );

      // Verify header and form elements
      expect(screen.getByText('Authorize Municipal Work Order')).toBeInTheDocument();

      // Submit approval
      const submitBtn = screen.getByRole('button', { name: /Confirm & Issue Work Order/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalledWith('wo-123');
      });
    });

    it('handles human override responsibility checkbox when required', async () => {
      const overrideRec: RecommendationListItem = {
        ...baseRec,
        requiresResponsibilityAcknowledgement: true,
        validation: {
          status: 'WARNING',
          issues: ['CREW_BUSY'],
          checks: [],
        },
      };

      const onSuccess = vi.fn();
      const onClose = vi.fn();
      const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
        if (url.includes('/approve')) {
          const body = JSON.parse(options?.body as string);
          expect(body.acknowledgeHumanOverrideResponsibility).toBe(true);
          return reply({
            recommendation: { ...overrideRec, reviewDecision: 'APPROVED' },
            workOrder: { id: 'wo-override-99', problemId: 'prob-001' },
          });
        }
        return reply({});
      });
      vi.stubGlobal('fetch', fetcher);

      render(
        <ApproveRecommendationModal
          recommendation={overrideRec}
          token="mock-token"
          onClose={onClose}
          onSuccess={onSuccess}
        />
      );

      // Fill in required override reason
      const reasonInput = screen.getByLabelText(/Approval reason/i);
      fireEvent.change(reasonInput, { target: { value: 'Override approved by municipal lead' } });

      // Checkbox should be present
      const checkbox = screen.getByRole('checkbox');
      expect(checkbox).not.toBeChecked();

      // Check the acknowledgment
      fireEvent.click(checkbox);
      expect(checkbox).toBeChecked();

      const submitBtn = screen.getByRole('button', { name: /Confirm & Issue Work Order/i });
      expect(submitBtn).not.toBeDisabled();
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalledWith('wo-override-99');
      });
    });
  });

  describe('RejectRecommendationModal', () => {
    it('validates mandatory reason and submits rejection', async () => {
      const onSuccess = vi.fn();
      const onClose = vi.fn();
      const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
        if (url.includes('/reject')) {
          const body = JSON.parse(options?.body as string);
          expect(body.reason).toBe('Duplicate incident report for same culvert.');
          return reply({ recommendation: { ...baseRec, reviewDecision: 'REJECTED' } });
        }
        return reply({});
      });
      vi.stubGlobal('fetch', fetcher);

      render(
        <RejectRecommendationModal
          recommendation={baseRec}
          token="mock-token"
          onClose={onClose}
          onSuccess={onSuccess}
        />
      );

      // Verify button is disabled initially without reason
      const submitBtn = screen.getByRole('button', { name: /Confirm Rejection/i });
      expect(submitBtn).toBeDisabled();

      // Enter reason and submit
      const textarea = screen.getByRole('textbox');
      fireEvent.change(textarea, {
        target: { value: 'Duplicate incident report for same culvert.' },
      });
      expect(submitBtn).not.toBeDisabled();
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalled();
      });
    });
  });

  describe('RegenerateRecommendationModal', () => {
    it('submits feedback for re-evaluation and triggers onSuccess callback', async () => {
      const onSuccess = vi.fn();
      const onClose = vi.fn();
      const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
        if (url.includes('/regenerate')) {
          const body = JSON.parse(options?.body as string);
          expect(body.reason).toBe('Need heavier machinery due to heavy downpour');
          return reply({ recommendation: baseRec });
        }
        return reply({});
      });
      vi.stubGlobal('fetch', fetcher);

      render(
        <RegenerateRecommendationModal
          recommendation={baseRec}
          token="mock-token"
          onClose={onClose}
          onSuccess={onSuccess}
        />
      );

      const textarea = screen.getByRole('textbox');
      fireEvent.change(textarea, {
        target: { value: 'Need heavier machinery due to heavy downpour' },
      });

      const submitBtn = screen.getByRole('button', { name: /Regenerate Assessment/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalled();
      });
    });
  });

  describe('EditRecommendationModal', () => {
    it('submits updated recommendation details and triggers onSuccess', async () => {
      const onSuccess = vi.fn();
      const onClose = vi.fn();
      const updatedDetail: RecommendationDetail = {
        ...baseRec,
        priority: 'CRITICAL',
        priorityScore: 95,
        reviewDecision: null,
        latitude: 6.9,
        longitude: 79.8,
        address: 'Test',
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

      const fetcher = vi.fn(async (url: string, options?: RequestInit) => {
        if (url.includes('/api/crews')) {
          return reply({
            items: [
              {
                id: 'crew-001',
                name: 'Drainage Squad Alpha',
                crewType: 'DRAINAGE',
                status: 'AVAILABLE',
              },
            ],
          });
        }
        if (options?.method === 'PATCH' || options?.method === 'PUT' || url.includes('/edit')) {
          return reply(updatedDetail);
        }
        return reply({});
      });
      vi.stubGlobal('fetch', fetcher);

      render(
        <EditRecommendationModal
          recommendation={baseRec}
          token="mock-token"
          onClose={onClose}
          onSuccess={onSuccess}
        />
      );

      const textarea = screen.getByPlaceholderText(/State the justification/i);
      fireEvent.change(textarea, { target: { value: 'Severe compounding risk' } });

      const submitBtn = screen.getByRole('button', { name: /Save Overrides/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalledWith(updatedDetail);
      });
    });
  });
});
