import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  getRecommendations,
  getRecommendationById,
  editRecommendation,
  approveRecommendation,
  rejectRecommendation,
  regenerateRecommendation,
  getReviewJob,
} from '../../../src/services/dispatchApi';
import type {
  RecommendationListItem,
  RecommendationDetail,
  ApproveRecommendationResponse,
  RejectRecommendationResponse,
  RegenerateRecommendationResponse,
  ReviewJob,
  PagedResult,
} from '../../../src/types/dispatch';

describe('Dispatch API Integration Tests (Member 4)', () => {
  const fakeToken = 'test-jwt-token-member4';
  const originalFetch = globalThis.fetch;

  function mockJsonResponse(data: unknown, status = 200): Response {
    return {
      ok: status >= 200 && status < 300,
      status,
      headers: new Headers({ 'content-type': 'application/json' }),
      json: async () => data,
    } as unknown as Response;
  }

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('getRecommendations sends correct query parameters and Authorization header', async () => {
    const mockPagedData: PagedResult<RecommendationListItem> = {
      items: [],
      totalItems: 0,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockPagedData));

    await getRecommendations(fakeToken, {
      page: 1,
      pageSize: 20,
      priority: 'HIGH',
      category: 'ROAD',
      reviewBucket: 'READY',
      search: 'pothole',
    });

    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    const [calledUrl, calledOptions] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit & { headers: Record<string, string> }];

    expect(calledUrl).toContain('/dispatch/recommendations?');
    expect(calledUrl).toContain('page=1');
    expect(calledUrl).toContain('pageSize=20');
    expect(calledUrl).toContain('priority=HIGH');
    expect(calledUrl).toContain('category=ROAD');
    expect(calledUrl).toContain('reviewBucket=READY');
    expect(calledUrl).toContain('search=pothole');
    expect(calledOptions.method).toBe('GET');
    expect(calledOptions.headers.Authorization).toBe(`Bearer ${fakeToken}`);
  });

  it('getRecommendationById queries specific recommendation endpoint with bearer authorization', async () => {
    const mockDetail = { recommendationId: 'rec-42', problemTitle: 'Water Pipe Burst' } as RecommendationDetail;
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockDetail));

    const result = await getRecommendationById(fakeToken, 'rec-42');

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/recommendations/rec-42', {
      method: 'GET',
      headers: { Authorization: `Bearer ${fakeToken}` },
    });
    expect(result.recommendationId).toBe('rec-42');
  });

  it('editRecommendation sends a PATCH with the override payload and JSON headers', async () => {
    const payload = { expectedRevision: 1, priority: 'CRITICAL', editReason: 'Escalated after second report' };
    const mockUpdated = { recommendationId: 'rec-1', priority: 'CRITICAL' } as RecommendationDetail;
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockUpdated));

    const result = await editRecommendation(fakeToken, 'rec-1', payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/recommendations/rec-1', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${fakeToken}` },
      body: JSON.stringify(payload),
    });
    expect(result.priority).toBe('CRITICAL');
  });

  it('approveRecommendation posts to the approve endpoint and returns the created work order', async () => {
    const payload = { reason: 'Reviewed', expectedRevision: 1 };
    const mockResponse: ApproveRecommendationResponse = {
      recommendationId: 'rec-1',
      decision: 'APPROVED',
      decidedBy: 'coordinator-1',
      decidedAt: '2026-10-01T00:00:00Z',
      workOrder: { id: 'wo-1', problemId: 'problem-1', crewId: 'crew-1', priority: 'HIGH', status: 'ASSIGNED', assignedAt: null, createdAt: '2026-10-01T00:00:00Z' },
    };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockResponse));

    const result = await approveRecommendation(fakeToken, 'rec-1', payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/recommendations/rec-1/approve', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${fakeToken}` },
      body: JSON.stringify(payload),
    });
    expect(result.workOrder.id).toBe('wo-1');
  });

  it('rejectRecommendation posts the rejection reason and expected revision', async () => {
    const payload = { reason: 'Crew reassigned to emergency ward', expectedRevision: 1 };
    const mockResponse: RejectRecommendationResponse = {
      recommendationId: 'rec-1',
      decision: 'REJECTED',
      decidedAt: '2026-10-01T00:00:00Z',
      decidedBy: 'coordinator-1',
      reason: payload.reason,
    };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockResponse));

    const result = await rejectRecommendation(fakeToken, 'rec-1', payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/recommendations/rec-1/reject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${fakeToken}` },
      body: JSON.stringify(payload),
    });
    expect(result.decision).toBe('REJECTED');
  });

  it('regenerateRecommendation queues a durable review job with a request id', async () => {
    const payload = { reason: 'Unavailable crew', expectedRevision: 1, requestId: 'req-1' };
    const mockResponse: RegenerateRecommendationResponse = { jobId: 'job-1', status: 'QUEUED', statusUrl: '/dispatch/review-jobs/job-1' };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockResponse));

    const result = await regenerateRecommendation(fakeToken, 'rec-1', payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/recommendations/rec-1/regenerate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${fakeToken}` },
      body: JSON.stringify(payload),
    });
    expect(result.jobId).toBe('job-1');
  });

  it('getReviewJob polls the review job status endpoint with bearer authorization', async () => {
    const mockJob: ReviewJob = {
      requestId: 'req-1', requestedBy: 'coordinator-1', origin: null, workflowRunId: 'wf-1',
      recommendationId: 'rec-1', expectedRevision: 1, updatedAt: '2026-10-01T00:00:00Z', chainId: null,
      parentJobId: null, correctionCount: null, evidenceRetryCount: null, nextAttemptAt: null,
      id: 'job-1', kind: 'VALIDATE', status: 'RUNNING', reason: 'Scheduled validation', error: null,
      resultRecommendationId: null, createdAt: '2026-10-01T00:00:00Z', attempts: 1,
    };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockJob));

    const result = await getReviewJob(fakeToken, 'job-1');

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/dispatch/review-jobs/job-1', {
      headers: { Authorization: `Bearer ${fakeToken}` },
    });
    expect(result.status).toBe('RUNNING');
  });
});
