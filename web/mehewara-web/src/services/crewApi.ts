import type {
  CrewListItem,
  CrewDetail,
  CrewQueryParams,
  CrewAvailabilityResponse,
} from '../types/crew';
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
 * Get paginated list of municipal crews with filtering by crewType and status
 */
export async function getCrews(
  token: string,
  params?: CrewQueryParams
): Promise<PagedResult<CrewListItem>> {
  const query = new URLSearchParams();
  if (params?.page) query.append('page', params.page.toString());
  if (params?.pageSize) query.append('pageSize', params.pageSize.toString());
  if (params?.crewType) query.append('crewType', params.crewType);
  if (params?.status) query.append('status', params.status);
  if (params?.search) query.append('search', params.search);

  const url = `${API_BASE}/crews${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<PagedResult<CrewListItem>>(res);
}

/**
 * Get detailed crew information by ID
 */
export async function getCrewById(token: string, crewId: string): Promise<CrewDetail> {
  const res = await fetch(`${API_BASE}/crews/${crewId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<CrewDetail>(res);
}

/**
 * Get currently available municipal crews (optionally filtered by type)
 */
export async function getAvailableCrews(
  token: string,
  crewType?: string,
  status?: string
): Promise<CrewAvailabilityResponse> {
  const query = new URLSearchParams();
  if (crewType) query.append('crewType', crewType);
  if (status) query.append('status', status);

  const url = `${API_BASE}/crews/availability${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<CrewAvailabilityResponse>(res);
}

export const getCrewAvailability = getAvailableCrews;

