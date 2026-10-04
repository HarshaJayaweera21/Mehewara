import type {
  CreateReportRequest,
  ReportResponse,
  ReportSummaryResponse,
  ReportPhotoDto,
  PagedResult,
  ReportFilterParams,
} from '../types/reports';
import { API_BASE, handleResponse, getAuthHeaders, buildQueryString } from './httpClient';

/**
 * Upload a photo for a report directly to Cloudinary via backend
 */
export async function uploadReportPhoto(token: string, file: File): Promise<ReportPhotoDto> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`${API_BASE}/reports/photos`, {
    method: 'POST',
    headers: getAuthHeaders(token, false),
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
    headers: getAuthHeaders(token, true),
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
  const url = `${API_BASE}/resident/reports${buildQueryString(params as Record<string, unknown>)}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<PagedResult<ReportSummaryResponse>>(res);
}

/**
 * Get complete report details by ID
 */
export async function getReportById(token: string, reportId: string): Promise<ReportResponse> {
  const res = await fetch(`${API_BASE}/reports/${reportId}`, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
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
  const url = `${API_BASE}/reports${buildQueryString(params as Record<string, unknown>)}`;

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(token, false),
  });

  return handleResponse<PagedResult<ReportSummaryResponse>>(res);
}
