export type ReportCategory =
  | 'ROAD'
  | 'DRAINAGE'
  | 'WASTE'
  | 'ELECTRICAL'
  | 'ENVIRONMENT';

export type ReportStatus =
  | 'PENDING'
  | 'PROCESSING'
  | 'ASSIGNED'
  | 'RESOLVED'
  | 'CANCELLED';

export interface ReportPhotoRequest {
  photoUrl: string;
  fileName?: string;
  mimeType?: string;
}

export interface CreateReportRequest {
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  address?: string;
  photos?: ReportPhotoRequest[];
}

export interface ReportPhotoDto {
  photoId: string;
  photoUrl: string;
  fileName?: string;
  mimeType?: string;
  uploadedAt: string;
}

export interface LinkedProblemDto {
  problemId: string;
  title: string;
  category: string;
  priority?: string;
  workStatus: string;
  linkedAt: string;
}

export interface ReportResponse {
  id: string;
  residentId: string;
  residentName?: string;
  residentEmail?: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  address?: string;
  status: string;
  photos: ReportPhotoDto[];
  linkedProblems: LinkedProblemDto[];
  createdAt: string;
  updatedAt: string;
}

export interface ReportSummaryResponse {
  id: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  address?: string;
  status: string;
  linkedProblemCount: number;
  firstPhotoUrl?: string;
  createdAt: string;
}

export interface PagedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
  sortBy?: string;
  sortDirection?: string;
}

export interface ReportFilterParams {
  page?: number;
  pageSize?: number;
  status?: string;
  category?: string;
  fromDate?: string;
  toDate?: string;
  search?: string;
  sortBy?: string;
  sortDirection?: string;
}
