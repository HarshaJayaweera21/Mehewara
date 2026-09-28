import type {
  RecommendationListItem,
  RecommendationDetail,
  RecommendationQueryParams,
  EditRecommendationRequest,
  ApproveRecommendationRequest,
  ApproveRecommendationResponse,
  RejectRecommendationRequest,
  RejectRecommendationResponse,
  RegenerateRecommendationRequest,
  RegenerateRecommendationResponse,
} from '../types/dispatch';
import type { PagedResult } from '../types/problems';
import type { ApiError } from '../types/auth';

const API_BASE = 'http://localhost:5194/api';

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let errorData: ApiError | null = null;
    try {
      errorData = await res.json();
    } catch {
      // response was not JSON
    }
    const message = errorData?.error?.message || `Request failed with status ${res.status}`;
    throw new Error(message);
  }
  return res.json();
}

/**
 * Get paginated list of Agent 3 dispatch recommendations
 */
export async function getRecommendations(
  token: string,
  params?: RecommendationQueryParams
): Promise<PagedResult<RecommendationListItem>> {
  const query = new URLSearchParams();
  if (params?.page) query.append('page', params.page.toString());
  if (params?.pageSize) query.append('pageSize', params.pageSize.toString());
  if (params?.priority) query.append('priority', params.priority);
  if (params?.reviewDecision) query.append('reviewDecision', params.reviewDecision);
  if (params?.status) query.append('status', params.status);
  if (params?.search) query.append('search', params.search);

  const url = `${API_BASE}/dispatch/recommendations${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<PagedResult<RecommendationListItem>>(res);
}

/**
 * Get detailed recommendation by ID with problem, reports, and validation issues
 */
export async function getRecommendationById(
  token: string,
  recommendationId: string
): Promise<RecommendationDetail> {
  const res = await fetch(`${API_BASE}/dispatch/recommendations/${recommendationId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<RecommendationDetail>(res);
}

/**
 * Human-in-the-Loop Override: Edit priority, score, recommended crew, or notes
 */
export async function editRecommendation(
  token: string,
  recommendationId: string,
  data: EditRecommendationRequest
): Promise<RecommendationListItem> {
  const res = await fetch(`${API_BASE}/dispatch/recommendations/${recommendationId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<RecommendationListItem>(res);
}

/**
 * Approve recommendation: Runs 10-point deterministic validation and creates WorkOrder
 */
export async function approveRecommendation(
  token: string,
  recommendationId: string,
  data: ApproveRecommendationRequest
): Promise<ApproveRecommendationResponse> {
  const res = await fetch(`${API_BASE}/dispatch/recommendations/${recommendationId}/approve`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<ApproveRecommendationResponse>(res);
}

/**
 * Reject recommendation: Records rejection reason in approval_history
 */
export async function rejectRecommendation(
  token: string,
  recommendationId: string,
  data: RejectRecommendationRequest
): Promise<RejectRecommendationResponse> {
  const res = await fetch(`${API_BASE}/dispatch/recommendations/${recommendationId}/reject`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<RejectRecommendationResponse>(res);
}

/**
 * Request regeneration: Resets status and triggers AI workflow regeneration
 */
export async function regenerateRecommendation(
  token: string,
  recommendationId: string,
  data: RegenerateRecommendationRequest
): Promise<RegenerateRecommendationResponse> {
  const res = await fetch(`${API_BASE}/dispatch/recommendations/${recommendationId}/regenerate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<RegenerateRecommendationResponse>(res);
}
