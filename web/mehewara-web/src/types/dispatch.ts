/**
 * Prioritization & Crew Dispatch Types for Member 3
 */

export type PriorityLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export type ValidationStatus = 'VALID' | 'WARNING' | 'REVISION_REQUIRED' | 'INVALID' | 'ERROR' | 'NOT_RUN';

export type ReviewDecision = 'APPROVED' | 'REJECTED' | 'REVISION_REQUIRED';

export interface RecommendationValidation {
  status: ValidationStatus | string;
  issues: string[];
  checks?: { code: string; passed: boolean; message: string }[];
  findings?: { code: string; message: string; evidenceRefs: string[]; correction: string }[];
  evidenceRefs?: string[];
}

export interface RecommendationListItem {
  recommendationId: string;
  revision: number;
  isCurrent: boolean;
  canApprove: boolean;
  previousRecommendationId: string | null;
  latestJob: ReviewJob | null;
  problemId: string;
  problemTitle: string;
  category: string;
  priority: PriorityLevel;
  priorityScore: number;
  priorityReasons: string[];
  requiredCrewType: string;
  recommendedCrewId: string | null;
  recommendedCrewName: string | null;
  recommendationReason: string;
  dispatchStrategy?: 'IMMEDIATE_QUICK_WIN' | 'URGENT_CRITICAL_PRIORITY' | 'CLUSTERED_EN_ROUTE' | 'STANDARD_DISPATCH' | string;
  estimatedDurationMinutes?: number | null;
  distanceKm?: number | null;
  estimatedTravelMinutes?: number | null;
  validation: RecommendationValidation;
  reviewDecision: ReviewDecision | null;
  createdAt: string;
}

export interface RecommendationDetail extends RecommendationListItem {
  validationHistory: { id: string; startedAt: string; completedAt: string | null; status: string; result: string | null }[];
  editHistory: { id: string; createdAt: string; reason: string | null; before: string; after: string }[];
  history: { recommendationId: string; previousRecommendationId: string | null; revision: number;
    createdAt: string; outputData: string | null; validationResult: string | null }[];
  problemDescription: string | null;
  latitude: number;
  longitude: number;
  address: string | null;
  reportCount: number;
  reportDescriptions: string[];
  recommendedCrewStatus: string | null;
  reviewReason: string | null;
  reviewedBy: string | null;
  reviewedAt: string | null;
  workOrderId: string | null;
}

export interface RecommendationQueryParams {
  page?: number;
  pageSize?: number;
  priority?: string;
  reviewDecision?: string;
  status?: string;
  search?: string;
}

export interface EditRecommendationRequest {
  expectedRevision: number;
  requiredCrewType?: string;
  priorityReasons?: string[];
  recommendationReason?: string;
  priority?: string;
  priorityScore?: number;
  recommendedCrewId?: string;
  editReason: string;
}
export interface ApproveRecommendationRequest { reason?: string; expectedRevision: number; }
export interface ApproveRecommendationResponse {
  recommendationId: string; decision: string; decidedBy: string; decidedAt: string;
  workOrder: { id: string; problemId: string; crewId: string; priority: string; status: string; assignedAt: string | null; createdAt: string };
}

export interface RejectRecommendationRequest {
  expectedRevision: number;
  reason: string;
}

export interface RejectRecommendationResponse {
  recommendationId: string;
  decision: string;
  decidedAt: string;
  decidedBy: string;
  reason: string;
}

export interface RegenerateRecommendationRequest {
  reason: string;
  expectedRevision: number;
  requestId: string;
}
export interface RegenerateRecommendationResponse {
  jobId: string;
  status: string;
  statusUrl: string;
}
export interface ReviewJob {
  id: string;
  kind: 'REGENERATE' | 'VALIDATE';
  status: 'QUEUED' | 'RUNNING' | 'COMPLETED' | 'FAILED';
  reason: string;
  error: string | null;
  resultRecommendationId: string | null;
  createdAt: string;
  attempts: number;
}
