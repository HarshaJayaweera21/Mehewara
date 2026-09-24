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
import type { ApiError } from '../types/auth';

const API_BASE = 'http://localhost:5194/api';

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let errorData: ApiError | null = null;
    try {
      errorData = await res.json();
    } catch {
      // response wasn't JSON
    }
    const message = errorData?.error?.message || `Request failed with status ${res.status}`;
    throw new Error(message);
  }
  return res.json();
}

/**
 * Get paginated list of municipal problems with optional filtering
 */
export async function getProblems(
  token: string,
  params?: GetProblemsParams
): Promise<PagedResult<ProblemResponse>> {
  const query = new URLSearchParams();
  if (params?.page) query.append('page', params.page.toString());
  if (params?.pageSize) query.append('pageSize', params.pageSize.toString());
  if (params?.category) query.append('category', params.category);
  if (params?.priority) query.append('priority', params.priority);
  if (params?.status) query.append('status', params.status);
  if (params?.search) query.append('search', params.search);
  if (params?.fromDate) query.append('fromDate', params.fromDate);
  if (params?.toDate) query.append('toDate', params.toDate);
  if (params?.sortBy) query.append('sortBy', params.sortBy);
  if (params?.sortDirection) query.append('sortDirection', params.sortDirection);

  const url = `${API_BASE}/problems${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<PagedResult<ProblemResponse>>(res);
}

/**
 * Get detailed problem information including linked reports summary
 */
export async function getProblemById(token: string, id: string): Promise<ProblemDetailResponse> {
  const res = await fetch(`${API_BASE}/problems/${id}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<ProblemDetailResponse>(res);
}

/**
 * Get full report records linked to a specific problem (including photos and resident info)
 */
export async function getProblemReports(token: string, id: string): Promise<ProblemReportResponse[]> {
  const res = await fetch(`${API_BASE}/problems/${id}/reports`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<ProblemReportResponse[]>(res);
}

/**
 * Create a new municipal problem (coordinator action)
 */
export async function createProblem(token: string, data: CreateProblemRequest): Promise<ProblemResponse> {
  const res = await fetch(`${API_BASE}/problems`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<ProblemResponse>(res);
}

/**
 * Get all uncertain reports flagged by AI Agent 2 for coordinator review
 */
export async function getUncertainReports(token: string): Promise<UncertainReportResponse[]> {
  const res = await fetch(`${API_BASE}/problems/uncertain-reports`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
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
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
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
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<ProblemResponse>(res);
}

