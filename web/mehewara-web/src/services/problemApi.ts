import type {
  ProblemResponse,
  ProblemDetailResponse,
  ProblemReportResponse,
  GetProblemsParams,
  CreateProblemRequest,
  PagedResult,
  UncertainReportResponse,
  LinkUncertainReportRequest,
  CreateProblemFromUncertainReportRequest,
} from '../types/problems';
import { API_BASE, handleResponse, getAuthHeaders, buildQueryString } from './httpClient';

/**
 * Get paginated list of municipal problems with optional filtering
 */
export async function getProblems(
  token: string,
  params?: GetProblemsParams
): Promise<PagedResult<ProblemResponse>> {
  const url = `${API_BASE}/problems${buildQueryString(params as Record<string, unknown>)}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<PagedResult<ProblemResponse>>(res);
}

/**
 * Get detailed problem information including linked reports summary
 */
export async function getProblemById(token: string, id: string): Promise<ProblemDetailResponse> {
  const res = await fetch(`${API_BASE}/problems/${id}`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<ProblemDetailResponse>(res);
}

/**
 * Get full report records linked to a specific problem (including photos and resident info)
 */
export async function getProblemReports(token: string, id: string): Promise<ProblemReportResponse[]> {
  const res = await fetch(`${API_BASE}/problems/${id}/reports`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<ProblemReportResponse[]>(res);
}

/**
 * Create a new municipal problem (coordinator action)
 */
export async function createProblem(token: string, data: CreateProblemRequest): Promise<ProblemResponse> {
  const res = await fetch(`${API_BASE}/problems`, {
    method: 'POST',
    headers: getAuthHeaders(token, true),
    body: JSON.stringify(data),
  });

  return handleResponse<ProblemResponse>(res);
}

/**
 * Get all uncertain reports flagged for coordinator review
 */
export async function getUncertainReports(token: string): Promise<UncertainReportResponse[]> {
  const res = await fetch(`${API_BASE}/problems/uncertain-reports`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<UncertainReportResponse[]>(res);
}

/**
 * Manually link an uncertain report to an existing active problem
 */
export async function linkUncertainReport(
  token: string,
  data: LinkUncertainReportRequest
): Promise<ProblemResponse> {
  const res = await fetch(`${API_BASE}/problems/uncertain-reports/link`, {
    method: 'POST',
    headers: getAuthHeaders(token, true),
    body: JSON.stringify(data),
  });

  return handleResponse<ProblemResponse>(res);
}

/**
 * Manually create a new problem from an uncertain report
 */
export async function createProblemFromUncertainReport(
  token: string,
  data: CreateProblemFromUncertainReportRequest
): Promise<ProblemResponse> {
  const res = await fetch(`${API_BASE}/problems/uncertain-reports/create`, {
    method: 'POST',
    headers: getAuthHeaders(token, true),
    body: JSON.stringify(data),
  });

  return handleResponse<ProblemResponse>(res);
}

/**
 * Cancel an unnecessary uncertain report, updating its status to CANCELLED
 */
export async function cancelUncertainReport(
  token: string,
  reportId: string,
  reason?: string
): Promise<{ message: string; reportId: string }> {
  const res = await fetch(`${API_BASE}/problems/uncertain-reports/${reportId}/cancel`, {
    method: 'POST',
    headers: getAuthHeaders(token, true),
    body: JSON.stringify({ reportId, reason }),
  });

  return handleResponse<{ message: string; reportId: string }>(res);
}
