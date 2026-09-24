"""
Mehewara AI Service — Problem Consolidation Schemas (Agent 2)

Defines strict Pydantic schemas for Agent 2 (Problem Consolidation Agent):
- Input contract: structured report from Agent 1 + source database context
- Output contract: deterministic consolidation decision (LINK_EXISTING | CREATE_NEW | UNCERTAIN)
- Candidate representations for new problem creation
"""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from schemas.report_analysis import MunicipalCategory, StructuredReport


class ConsolidationDecision(str, Enum):
    """Authoritative decisions produced by Agent 2."""
    LINK_EXISTING = "LINK_EXISTING"  # Report belongs to an existing identified Problem
    CREATE_NEW = "CREATE_NEW"        # Report represents a distinct incident; create a new Problem
    UNCERTAIN = "UNCERTAIN"          # Conflicting or insufficient evidence; safe failure without mutation


class SourceReportPayload(BaseModel):
    """Authoritative database record of the report supplied by ASP.NET Core."""
    report_id: UUID = Field(..., alias="reportId")
    description: str
    category: str
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    address: str | None = None
    created_at: datetime | None = Field(default=None, alias="createdAt")

    model_config = {"populate_by_name": True, "serialize_by_alias": True}


class ProblemConsolidationInputSchema(BaseModel):
    """
    Input schema ingested by Agent 2.
    Combines Agent 1's structured observations with the authoritative database record.
    """
    structured_report: StructuredReport = Field(
        ...,
        alias="structuredReport",
        description="Structured report facts extracted by Agent 1",
    )
    source_report: SourceReportPayload = Field(
        ...,
        alias="sourceReport",
        description="Raw authoritative report metadata from PostgreSQL",
    )

    model_config = {"populate_by_name": True, "serialize_by_alias": True}


class NewProblemCandidate(BaseModel):
    """Candidate representation when Agent 2 decides CREATE_NEW."""
    title: str = Field(
        ...,
        min_length=5,
        max_length=200,
        description="Concise, factual title of the municipal problem (e.g. 'Road flooding near Central College')",
    )
    description: str | None = Field(
        default=None,
        description="Summary of the problem based on observed reports",
    )
    category: MunicipalCategory = Field(
        ...,
        description="Standard municipal category matching the database enum",
    )
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    address: str | None = None

    model_config = {"populate_by_name": True, "serialize_by_alias": True}


class ProblemConsolidationOutputSchema(BaseModel):
    """
    Authoritative output contract of Agent 2.
    
    Guardrails enforced:
    - If decision is LINK_EXISTING, problem_id must NOT be null.
    - If decision is CREATE_NEW, new_problem must NOT be null.
    - Evidence must be concise observable points, not hidden reasoning.
    """
    report_id: UUID = Field(
        ...,
        alias="reportId",
        description="UUID of the incoming resident report being consolidated",
    )
    decision: ConsolidationDecision = Field(
        ...,
        description="The consolidation decision: LINK_EXISTING, CREATE_NEW, or UNCERTAIN",
    )
    problem_id: UUID | None = Field(
        default=None,
        alias="problemId",
        description="UUID of the existing Problem if LINK_EXISTING; null if CREATE_NEW or UNCERTAIN",
    )
    related_report_ids: list[UUID] = Field(
        default_factory=list,
        alias="relatedReportIds",
        description="List of all report UUIDs (including this report) that belong to this Problem",
    )
    summary: str = Field(
        ...,
        min_length=10,
        description="Concise factual explanation of the consolidation decision",
    )
    evidence: list[str] = Field(
        default_factory=list,
        description="List of observable criteria supporting the decision (e.g. ['Same category', 'Close proximity'])",
    )
    new_problem: NewProblemCandidate | None = Field(
        default=None,
        alias="newProblem",
        description="Populated ONLY when decision is CREATE_NEW. Contains title, initial synthesized description, category, and coordinates.",
    )
    updated_problem_description: str | None = Field(
        default=None,
        alias="updatedProblemDescription",
        description="Updated synthesized summary of all reports under the Problem, enriched with new facts from the latest report. Stored in Problem.Description.",
    )
    structured_report: StructuredReport | None = Field(
        default=None,
        alias="structuredReport",
        description="Full structured report output from Agent 1 passed through for downstream consumption by Agent 3 (Priority & Crew Recommendation).",
    )
    analyzed_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        alias="analyzedAt",
    )

    @field_validator("decision", mode="before")
    @classmethod
    def validate_decision(cls, value: Any) -> ConsolidationDecision:
        """Safely coerce strings to ConsolidationDecision enum."""
        if isinstance(value, ConsolidationDecision):
            return value
        val_str = str(value).strip().upper()
        try:
            return ConsolidationDecision(val_str)
        except ValueError:
            return ConsolidationDecision.UNCERTAIN

    model_config = {
        "populate_by_name": True,
        "serialize_by_alias": True,
        "json_schema_extra": {
            "example": {
                "reportId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                "decision": "LINK_EXISTING",
                "problemId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
                "relatedReportIds": [
                    "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "8a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d",
                ],
                "summary": "The report describes the same water overflow at Central College as existing problem P023.",
                "evidence": [
                    "Same municipal category: DRAINAGE",
                    "Distance is less than 45 meters",
                    "Both describe blocked stormwater drain",
                ],
                "newProblem": None,
                "analyzedAt": "2026-09-22T10:00:00Z",
            }
        },
    }
