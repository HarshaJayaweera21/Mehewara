"""Agent 4's structured, evidence-referenced review contract."""
from typing import Literal
from pydantic import BaseModel, Field


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
    policy_version: str = Field(default="agent4-v1", alias="policyVersion")
    evidence_hash: str | None = Field(default=None, alias="evidenceHash")
    input_data: dict = Field(default_factory=dict, alias="inputData")
    tool_results: dict = Field(default_factory=dict, alias="toolResults")
    started_at: str = Field(alias="startedAt")
    completed_at: str = Field(alias="completedAt")
    model_config = {"populate_by_name": True}
