"""Agent 4's structured, evidence-referenced review contract."""
from typing import Literal
from pydantic import BaseModel, Field


class RecommendationForReview(BaseModel):
    """Independent strict checks; do not fill missing Agent 3 fields or rewrite them."""
    problemId: str
    priority: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    priorityScore: int = Field(ge=0, le=100)
    priorityReasons: list[str] = Field(min_length=1)
    requiredCrewType: Literal["ROAD", "DRAINAGE", "WASTE", "ELECTRICAL", "ENVIRONMENT"]
    recommendedCrewId: str | None
    recommendationReason: str = Field(min_length=10)
    estimatedDurationMinutes: int = Field(ge=10, le=2880)
    distanceKm: float | None = Field(default=None, ge=0)
    estimatedTravelMinutes: int | None = Field(default=None, ge=0)
    dispatchStrategy: Literal["IMMEDIATE_QUICK_WIN", "URGENT_CRITICAL_PRIORITY", "STANDARD_DISPATCH"]
    model_config = {"strict": True, "allow_inf_nan": False}


class EvidenceFinding(BaseModel):
    code: str
    message: str
    evidence_refs: list[str] = Field(default_factory=list, alias="evidenceRefs")
    correction: str
    model_config = {"populate_by_name": True}


class EvidenceReview(BaseModel):
    supported: bool
    findings: list[EvidenceFinding] = Field(default_factory=list)
    evidence_refs: list[str] = Field(min_length=1, alias="evidenceRefs")
    model_config = {"populate_by_name": True}


class SafetyValidation(BaseModel):
    status: Literal["VALID", "REVISION_REQUIRED", "INVALID", "ERROR", "NOT_RUN"]
    issues: list[str] = Field(default_factory=list)
    checks: list[dict] = Field(default_factory=list)
    findings: list[dict] = Field(default_factory=list)
    evidence_refs: list[str] = Field(default_factory=list, alias="evidenceRefs")
    policy_version: str = Field(default="agent4-v2", alias="policyVersion")
    evidence_hash: str | None = Field(default=None, alias="evidenceHash")
    snapshot_hash: str | None = Field(default=None, alias="snapshotHash")
    snapshot_at: str | None = Field(default=None, alias="snapshotAt")
    recommendation_id: str | None = Field(default=None, alias="recommendationId")
    recommendation_revision: int | None = Field(default=None, alias="recommendationRevision")
    suggested_action: Literal["APPROVAL_ELIGIBLE", "REGENERATE", "WAIT_FOR_CREW", "RETRY_VALIDATION", "REVIEW_INPUT"] = Field(alias="suggestedAction")
    input_data: dict = Field(default_factory=dict, alias="inputData")
    tool_results: dict = Field(default_factory=dict, alias="toolResults")
    started_at: str = Field(alias="startedAt")
    completed_at: str = Field(alias="completedAt")
    model_config = {"populate_by_name": True}
