import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  getProblems,
  getProblemById,
  getProblemReports,
  createProblem,
  linkUncertainReport,
  createProblemFromUncertainReport,
  cancelUncertainReport,
} from '../../../src/services/problemApi';
import type {
  ProblemResponse,
  ProblemDetailResponse,
  ProblemReportResponse,
  LinkUncertainReportRequest,
  CreateProblemRequest,
  PagedResult,
} from '../../../src/types/problems';

describe('Problem API Integration Tests (Member 2)', () => {
  const fakeToken = 'test-jwt-token-member2';
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

  it('getProblems sends correct query parameters and Authorization header', async () => {
    const mockPagedData: PagedResult<ProblemResponse> = {
      items: [
        {
          id: 'prob-1',
          title: 'Damaged Asphalt on Main St',
          description: 'Pothole cluster',
          category: 'ROADS',
          latitude: 6.9271,
          longitude: 79.8612,
          address: 'Main St',
          priority: 'HIGH',
          priorityScore: 75,
          status: 'IN_PROGRESS',
          relatedReportCount: 3,
          createdAt: '2026-03-29T10:00:00Z',
          updatedAt: '2026-03-29T10:00:00Z',
        },
      ],
      totalItems: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockPagedData));

    const result = await getProblems(fakeToken, {
      page: 1,
      pageSize: 10,
      category: 'ROADS',
      priority: 'HIGH',
      status: 'IN_PROGRESS',
      search: 'Asphalt',
    });

    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    const [calledUrl, calledOptions] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit & { headers: Record<string, string> }];

    expect(calledUrl).toContain('/api/problems?');
    expect(calledUrl).toContain('page=1');
    expect(calledUrl).toContain('pageSize=10');
    expect(calledUrl).toContain('category=ROADS');
    expect(calledUrl).toContain('priority=HIGH');
    expect(calledUrl).toContain('status=IN_PROGRESS');
    expect(calledUrl).toContain('search=Asphalt');

    expect(calledOptions.method).toBe('GET');
    expect(calledOptions.headers.Authorization).toBe(`Bearer ${fakeToken}`);
    expect(result.items).toHaveLength(1);
    expect(result.items[0].id).toBe('prob-1');
  });

  it('getProblemById queries specific problem endpoint with bearer authorization', async () => {
    const mockDetail: ProblemDetailResponse = {
      id: 'prob-42',
      title: 'Water Pipe Burst',
      description: 'Pipeline rupture flooding road',
      category: 'WATER',
      latitude: 6.91,
      longitude: 79.85,
      address: 'Galle Road',
      priority: 'CRITICAL',
      priorityScore: 95,
      status: 'IDENTIFIED',
      relatedReports: [],
      createdAt: '2026-03-29T08:00:00Z',
      updatedAt: '2026-03-29T08:00:00Z',
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockDetail));

    const result = await getProblemById(fakeToken, 'prob-42');

    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    const [calledUrl, calledOptions] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit & { headers: Record<string, string> }];

    expect(calledUrl).toBe('http://localhost:5194/api/problems/prob-42');
    expect(calledOptions.method).toBe('GET');
    expect(calledOptions.headers.Authorization).toBe(`Bearer ${fakeToken}`);
    expect(result.title).toBe('Water Pipe Burst');
  });

  it('getProblemReports retrieves full linked report records for problem', async () => {
    const mockReports: ProblemReportResponse[] = [
      {
        id: 'rep-101',
        residentId: 'user-01',
        residentName: 'Perera',
        description: 'Deep pothole damaging vehicles',
        category: 'ROADS',
        latitude: 6.92,
        longitude: 79.86,
        address: 'Main St',
        status: 'LINKED',
        photoUrls: ['https://example.com/pothole.jpg'],
        createdAt: '2026-03-29T09:00:00Z',
        updatedAt: '2026-03-29T09:00:00Z',
      },
    ];

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockReports));

    const result = await getProblemReports(fakeToken, 'prob-42');

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/problems/prob-42/reports', {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${fakeToken}`,
      },
    });
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('rep-101');
  });

  it('createProblem sends POST payload with JSON headers', async () => {
    const newProblemPayload: CreateProblemRequest = {
      title: 'Large Sinkhole near Bus Stand',
      category: 'ROADS',
      latitude: 6.9271,
      longitude: 79.8612,
      address: 'Main Street, Pettah',
      description: 'Dangerous depression forming on the road',
    };

    const mockCreated: ProblemResponse = {
      id: 'prob-99',
      ...newProblemPayload,
      description: newProblemPayload.description || null,
      address: newProblemPayload.address || null,
      priority: 'CRITICAL',
      priorityScore: 90,
      status: 'IDENTIFIED',
      relatedReportCount: 0,
      createdAt: '2026-03-29T11:00:00Z',
      updatedAt: '2026-03-29T11:00:00Z',
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockCreated));

    const result = await createProblem(fakeToken, newProblemPayload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/problems', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${fakeToken}`,
      },
      body: JSON.stringify(newProblemPayload),
    });
    expect(result.id).toBe('prob-99');
  });

  it('linkUncertainReport invokes coordinator link endpoint with notes', async () => {
    const linkPayload: LinkUncertainReportRequest = {
      reportId: 'rep-500',
      problemId: 'prob-100',
      coordinatorNotes: 'Verified via photo to be duplicate of Main St pothole',
    };

    const mockResponse: ProblemResponse = {
      id: 'prob-100',
      title: 'Main St Pothole',
      description: 'Large road crater',
      category: 'ROADS',
      latitude: 6.92,
      longitude: 79.86,
      address: 'Main St',
      priority: 'HIGH',
      priorityScore: 75,
      status: 'IN_PROGRESS',
      relatedReportCount: 4,
      createdAt: '2026-03-29T07:00:00Z',
      updatedAt: '2026-03-29T07:00:00Z',
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockResponse));

    const result = await linkUncertainReport(fakeToken, linkPayload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/problems/uncertain-reports/link', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${fakeToken}`,
      },
      body: JSON.stringify(linkPayload),
    });
    expect(result.id).toBe('prob-100');
  });

  it('createProblemFromUncertainReport triggers autonomous problem creation', async () => {
    const createPayload = {
      reportId: 'rep-777',
      title: 'Fallen Electric Post',
      category: 'ELECTRICAL',
      latitude: 6.92,
      longitude: 79.86,
    };

    const mockCreated: ProblemResponse = {
      id: 'prob-777',
      title: 'Fallen Electric Post',
      description: null,
      category: 'ELECTRICAL',
      latitude: 6.92,
      longitude: 79.86,
      address: null,
      priority: 'CRITICAL',
      priorityScore: 90,
      status: 'IDENTIFIED',
      relatedReportCount: 1,
      createdAt: '2026-03-29T12:00:00Z',
      updatedAt: '2026-03-29T12:00:00Z',
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockCreated));

    const result = await createProblemFromUncertainReport(fakeToken, createPayload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/problems/uncertain-reports/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${fakeToken}`,
      },
      body: JSON.stringify(createPayload),
    });
    expect(result.id).toBe('prob-777');
  });

  it('cancelUncertainReport triggers report cancellation', async () => {
    const mockCancelResponse = {
      message: 'Report cancelled successfully',
      reportId: 'rep-888',
    };

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockCancelResponse));

    const result = await cancelUncertainReport(fakeToken, 'rep-888', 'Spam report duplicate');

    expect(globalThis.fetch).toHaveBeenCalledWith(
      'http://localhost:5194/api/problems/uncertain-reports/rep-888/cancel',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${fakeToken}`,
        },
        body: JSON.stringify({ reportId: 'rep-888', reason: 'Spam report duplicate' }),
      }
    );
    expect(result.reportId).toBe('rep-888');
  });
});
