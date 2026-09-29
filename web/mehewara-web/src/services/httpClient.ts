import type { ApiError } from '../types/common';

export const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5194/api';

/**
 * Handles HTTP response parsing and uniform error/401 handling
 */
export async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    if (res.status === 401) {
      localStorage.removeItem('mehewara_token');
      localStorage.removeItem('mehewara_user');
      window.dispatchEvent(new Event('auth:unauthorized'));
    }

    let errorData: ApiError | null = null;
    try {
      errorData = await res.json();
    } catch {
      // Response wasn't JSON
    }

    const message =
      errorData?.error?.message ||
      (res.status === 401
        ? 'Session expired. Please log in again.'
        : `Request failed with status ${res.status}`);

    throw new Error(message);
  }

  // Handle empty responses (204 No Content)
  if (res.status === 204) {
    return {} as T;
  }

  const contentType = res.headers?.get ? res.headers.get('content-type') : null;
  if (!contentType || contentType.includes('application/json')) {
    return res.json();
  }

  return {} as T;
}

/**
 * Creates standard HTTP headers including optional JSON content-type and Bearer token
 */
export function getAuthHeaders(token?: string, isJson: boolean = true): HeadersInit {
  const activeToken = token || localStorage.getItem('mehewara_token') || '';
  const headers: Record<string, string> = {};

  if (isJson) {
    headers['Content-Type'] = 'application/json';
  }
  if (activeToken) {
    headers['Authorization'] = `Bearer ${activeToken}`;
  }

  return headers;
}

/**
 * Cleanly serializes query parameters into a URL query string
 */
export function buildQueryString(params?: Record<string, unknown>): string {
  if (!params) return '';
  const query = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      query.append(key, String(value));
    }
  });

  const queryString = query.toString();
  return queryString ? `?${queryString}` : '';
}
