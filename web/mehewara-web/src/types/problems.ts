export type ProblemCategory =
  | 'DRAINAGE'
  | 'ROAD'
  | 'WASTE'
  | 'ELECTRICAL'
  | 'ENVIRONMENT';

export type ProblemPriority =
  | 'LOW'
  | 'MEDIUM'
  | 'HIGH'
  | 'CRITICAL';

export type ProblemStatus =
  | 'IDENTIFIED'
  | 'AWAITING_ASSIGNMENT'
  | 'ASSIGNED'
  | 'IN_PROGRESS'
  | 'RESOLVED'
  | 'CLOSED';

export interface ProblemResponse {
  id: string;
  title: string;
  description: string | null;
  category: ProblemCategory | string;
  latitude: number;
  longitude: number;
  address: string | null;
  priority: ProblemPriority | string | null;
  priorityScore: number | null;
  status: ProblemStatus | string;
  relatedReportCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface RelatedReportSummary {
  reportId: string;
  description: string;
  category: string;
  status: string;
  address: string | null;
  latitude: number;
  longitude: number;
  firstPhotoUrl: string | null;
  createdAt: string;
}

export interface ProblemDetailResponse {
  id: string;
  title: string;
  description: string | null;
  category: ProblemCategory | string;
  latitude: number;
  longitude: number;
  address: string | null;
  priority: ProblemPriority | string | null;
  priorityScore: number | null;
  status: ProblemStatus | string;
  relatedReports: RelatedReportSummary[];
  createdAt: string;
  updatedAt: string;
}

export interface ProblemReportResponse {
  id: string;
  residentId: string;
  residentName: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  address: string | null;
  status: string;
  photoUrls: string[];
  createdAt: string;
  updatedAt: string;
}

export interface GetProblemsParams {
  page?: number;
  pageSize?: number;
  category?: string;
  priority?: string;
  status?: string;
  search?: string;
  fromDate?: string;
  toDate?: string;
  sortBy?: string;
  sortDirection?: string;
}

export interface CreateProblemRequest {
  title: string;
  category: string;
  description?: string;
  latitude: number;
  longitude: number;
  address?: string;
}

export interface PagedResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
  sortBy?: string;
  sortDirection?: string;
}

export interface NearbyCandidateProblemSummary {
  problemId: string;
  title: string;
  category: string;
  address: string | null;
  distanceMeters: number;
  reportCount: number;
}

export interface UncertainReportResponse {
  reportId: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  address: string | null;
  residentName: string;
  createdAt: string;
  photoUrls: string[];
  aiUncertaintyReason: string | null;
  aiEvidence: string[];
  nearbyCandidates: NearbyCandidateProblemSummary[];
}

export interface LinkUncertainReportRequest {
  reportId: string;
  problemId: string;
  coordinatorNotes?: string;
}

export interface CreateProblemFromUncertainReportRequest {
  reportId: string;
  title: string;
  description?: string;
  category: string;
  latitude: number;
  longitude: number;
  address?: string;
  coordinatorNotes?: string;
}

