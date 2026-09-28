/**
 * Prioritization & Crew Dispatch Types for Member 3
 */

export type PriorityLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export type ValidationStatus = 'VALID' | 'WARNING' | 'REVISION_REQUIRED' | 'INVALID';

export type ReviewDecision = 'APPROVED' | 'REJECTED' | 'REVISION_REQUIRED';

export interface RecommendationValidation {
  status: ValidationStatus | string;
  issues: string[];
}

export interface RecommendationListItem {
  recommendationId: string;
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
  validation: RecommendationValidation;
  reviewDecision: ReviewDecision | null;
  createdAt: string;
}

export interface RecommendationDetail extends RecommendationListItem {
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
  problemTitle?: string;
  priority?: string;
  priorityScore?: number;
  requiredCrewType?: string;
  recommendedCrewId?: string;
  recommendationReason?: string;
  notes?: string;
}

export interface ApproveRecommendationRequest {
  instructions?: string;
  notes?: string;
}

export interface ApproveRecommendationResponse {
  workOrderId: string;
  problemId: string;
  crewId: string;
  status: string;
  assignedAt: string;
  approvalHistoryId: string;
}

export interface RejectRecommendationRequest {
  reason: string;
}

export interface RejectRecommendationResponse {
  recommendationId: string;
  status: string;
  rejectedAt: string;
  reason: string;
}

export interface RegenerateRecommendationRequest {
  feedback?: string;
}

export interface RegenerateRecommendationResponse {
  recommendationId: string;
  status: string;
  regeneratedAt: string;
}
