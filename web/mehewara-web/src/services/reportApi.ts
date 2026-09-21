import type {
  CreateReportRequest,
  ReportResponse,
  ReportSummaryResponse,
  ReportPhotoDto,
  PagedResult,
  ReportFilterParams,
} from '../types/reports';
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
 * Upload a photo for a report directly to Cloudinary via backend
 */
export async function uploadReportPhoto(token: string, file: File): Promise<ReportPhotoDto> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`${API_BASE}/reports/photos`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });

  return handleResponse<ReportPhotoDto>(res);
}

/**
 * Submit a new citizen report
 */
export async function createReport(token: string, data: CreateReportRequest): Promise<ReportResponse> {
  const res = await fetch(`${API_BASE}/reports`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return handleResponse<ReportResponse>(res);
}

/**
 * Get personal submitted reports for the logged-in resident
 */
export async function getResidentReports(
  token: string,
  params?: { page?: number; pageSize?: number; status?: string; sortBy?: string; sortDirection?: string }
): Promise<PagedResult<ReportSummaryResponse>> {
  const query = new URLSearchParams();
  if (params?.page) query.append('page', params.page.toString());
  if (params?.pageSize) query.append('pageSize', params.pageSize.toString());
  if (params?.status) query.append('status', params.status);
  if (params?.sortBy) query.append('sortBy', params.sortBy);
  if (params?.sortDirection) query.append('sortDirection', params.sortDirection);

  const url = `${API_BASE}/resident/reports${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<PagedResult<ReportSummaryResponse>>(res);
}

/**
 * Get complete report details by ID
 */
export async function getReportById(token: string, reportId: string): Promise<ReportResponse> {
  const res = await fetch(`${API_BASE}/reports/${reportId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<ReportResponse>(res);
}

/**
 * Coordinator endpoint: Get all reports with filtering and pagination
 */
export async function getAllReports(
  token: string,
  params?: ReportFilterParams
): Promise<PagedResult<ReportSummaryResponse>> {
  const query = new URLSearchParams();
  if (params?.page) query.append('page', params.page.toString());
  if (params?.pageSize) query.append('pageSize', params.pageSize.toString());
  if (params?.status) query.append('status', params.status);
  if (params?.category) query.append('category', params.category);
  if (params?.search) query.append('search', params.search);
  if (params?.fromDate) query.append('fromDate', params.fromDate);
  if (params?.toDate) query.append('toDate', params.toDate);
  if (params?.sortBy) query.append('sortBy', params.sortBy);
  if (params?.sortDirection) query.append('sortDirection', params.sortDirection);

  const url = `${API_BASE}/reports${query.toString() ? `?${query.toString()}` : ''}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return handleResponse<PagedResult<ReportSummaryResponse>>(res);
}
