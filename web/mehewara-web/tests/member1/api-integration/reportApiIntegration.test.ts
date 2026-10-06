import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  uploadReportPhoto,
  createReport,
  getResidentReports,
  getReportById,
  getAllReports,
} from '../../../src/services/reportApi';
import { loginWithCredentials, registerResident } from '../../../src/services/api';
import type { CreateReportRequest, ReportResponse, ReportSummaryResponse, ReportPhotoDto, PagedResult } from '../../../src/types/reports';

describe('Report & Auth API Integration Tests (Member 1)', () => {
  const fakeToken = 'test-jwt-token-member1';
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

  it('createReport sends POST payload with JSON headers and bearer authorization', async () => {
    const payload: CreateReportRequest = {
      category: 'ROAD',
      description: 'Deep pothole damaging vehicles near the bus stand',
      latitude: 6.9271,
      longitude: 79.8612,
      address: 'Main Street, Pettah',
    };
    const mockCreated: ReportResponse = {
      id: 'rep-99',
      ...payload,
      status: 'PENDING',
      linkedProblemCount: 0,
      photos: [],
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    } as unknown as ReportResponse;

    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockCreated));

    const result = await createReport(fakeToken, payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/reports', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${fakeToken}` },
      body: JSON.stringify(payload),
    });
    expect(result.id).toBe('rep-99');
  });

  it('uploadReportPhoto sends multipart form data without a JSON content-type header', async () => {
    const mockUploaded: ReportPhotoDto = { photoId: 'photo-1', photoUrl: 'https://cdn.example.com/photo-1.jpg', fileName: 'pothole.jpg', mimeType: 'image/jpeg' };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockUploaded));

    const file = new File(['fake-image-bytes'], 'pothole.jpg', { type: 'image/jpeg' });
    const result = await uploadReportPhoto(fakeToken, file);

    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    const [calledUrl, calledOptions] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit & { headers: Record<string, string>; body: FormData }];
    expect(calledUrl).toBe('http://localhost:5194/api/reports/photos');
    expect(calledOptions.method).toBe('POST');
    expect(calledOptions.headers.Authorization).toBe(`Bearer ${fakeToken}`);
    expect(calledOptions.headers['Content-Type']).toBeUndefined();
    expect(calledOptions.body).toBeInstanceOf(FormData);
    expect(result.photoId).toBe('photo-1');
  });

  it('getResidentReports sends correct query parameters and Authorization header', async () => {
    const mockPagedData: PagedResult<ReportSummaryResponse> = {
      items: [],
      totalItems: 0,
      page: 1,
      pageSize: 12,
      totalPages: 1,
    } as unknown as PagedResult<ReportSummaryResponse>;
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockPagedData));

    await getResidentReports(fakeToken, { page: 1, pageSize: 12, status: 'PENDING' });

    const [calledUrl, calledOptions] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit & { headers: Record<string, string> }];
    expect(calledUrl).toContain('/resident/reports?');
    expect(calledUrl).toContain('page=1');
    expect(calledUrl).toContain('pageSize=12');
    expect(calledUrl).toContain('status=PENDING');
    expect(calledOptions.method).toBe('GET');
    expect(calledOptions.headers.Authorization).toBe(`Bearer ${fakeToken}`);
  });

  it('getReportById queries the specific report endpoint with bearer authorization', async () => {
    const mockReport = { id: 'rep-42', description: 'Water Pipe Burst' } as ReportResponse;
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockReport));

    const result = await getReportById(fakeToken, 'rep-42');

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/reports/rep-42', {
      method: 'GET',
      headers: { Authorization: `Bearer ${fakeToken}` },
    });
    expect(result.id).toBe('rep-42');
  });

  it('getAllReports (coordinator view) applies filter parameters', async () => {
    const mockPagedData: PagedResult<ReportSummaryResponse> = {
      items: [],
      totalItems: 0,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    } as unknown as PagedResult<ReportSummaryResponse>;
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse(mockPagedData));

    await getAllReports(fakeToken, { status: 'RESOLVED', category: 'DRAINAGE' } as never);

    const [calledUrl] = vi.mocked(globalThis.fetch).mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toContain('/reports?');
    expect(calledUrl).toContain('status=RESOLVED');
    expect(calledUrl).toContain('category=DRAINAGE');
  });

  it('loginWithCredentials posts email and password and does not trigger session-expired handling on failure', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse({ accessToken: 'token-1', user: { id: 'user-1', role: 'RESIDENT' } }));

    const result = await loginWithCredentials('resident@example.com', 'Resident@123');

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'resident@example.com', password: 'Resident@123' }),
    });
    expect(result.accessToken).toBe('token-1');
  });

  it('registerResident posts the registration payload to the register endpoint', async () => {
    const payload = { firstName: 'Kasun', lastName: 'Perera', email: 'kasun@example.com', password: 'Secret@123' };
    globalThis.fetch = vi.fn().mockResolvedValue(mockJsonResponse({ accessToken: 'token-2', user: { id: 'user-2', role: 'RESIDENT' } }));

    const result = await registerResident(payload);

    expect(globalThis.fetch).toHaveBeenCalledWith('http://localhost:5194/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    expect(result.accessToken).toBe('token-2');
  });
});
