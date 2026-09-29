import type {
  CrewListItem,
  CrewDetail,
  CrewQueryParams,
  CrewAvailabilityResponse,
} from '../types/crew';
import type { PagedResult } from '../types/common';
import { API_BASE, handleResponse, getAuthHeaders, buildQueryString } from './httpClient';

/**
 * Get paginated list of municipal crews with filtering by crewType and status
 */
export async function getCrews(
  token: string,
  params?: CrewQueryParams
): Promise<PagedResult<CrewListItem>> {
  const url = `${API_BASE}/crews${buildQueryString(params as Record<string, unknown>)}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<PagedResult<CrewListItem>>(res);
}

/**
 * Get detailed crew information by ID
 */
export async function getCrewById(token: string, crewId: string): Promise<CrewDetail> {
  const res = await fetch(`${API_BASE}/crews/${crewId}`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
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
  const url = `${API_BASE}/crews/availability${buildQueryString({ crewType, status })}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<CrewAvailabilityResponse>(res);
}

export const getCrewAvailability = getAvailableCrews;
