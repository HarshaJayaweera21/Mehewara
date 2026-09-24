"""
Mehewara AI Service — Pydantic Schemas for Agent 3 (Prioritization & Crew Recommendation)

Authoritative schema contracts for:
- PriorityLevel and CrewType enumerations
- Input contract ingested by Agent 3 from state & tools
- Structured output contract emitted by Agent 3 and persisted into PostgreSQL
"""

from __future__ import annotations

from enum import Enum
from typing import Any
from pydantic import BaseModel, Field


class PriorityLevel(str, Enum):
    """Authoritative priority tiers matching municipal dispatch criteria."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class CrewType(str, Enum):
    """Authoritative municipal crew types matching backend enum."""
    DRAINAGE = "DRAINAGE"
    ROAD = "ROAD"
    WASTE = "WASTE"
    ELECTRICAL = "ELECTRICAL"
    ENVIRONMENT = "ENVIRONMENT"


class PriorityRecommendationInput(BaseModel):
    """
    Input schema ingested by Agent 3.
    Assembles problem metadata, Agent 1 structured observations, and real-time crew availability.
    """
    problem_id: str | None = Field(default=None, alias="problemId")
    title: str = Field(..., min_length=3, description="Problem title or concise summary")
    description: str | None = Field(default=None, description="Consolidated problem description")
    category: str = Field(..., description="Municipal category (e.g. DRAINAGE, ROAD, ELECTRICAL)")
    latitude: float = Field(default=0.0, ge=-90.0, le=90.0)
    longitude: float = Field(default=0.0, ge=-180.0, le=180.0)
    address: str | None = Field(default=None)
    report_count: int = Field(default=1, ge=1, alias="reportCount")
    structured_report: dict[str, Any] | None = Field(
        default=None,
        alias="structuredReport",
        description="Factual observations extracted by Agent 1 (ADR-05 passthrough)",
    )

    model_config = {"populate_by_name": True, "serialize_by_alias": True}


class PriorityRecommendationOutput(BaseModel):
    """
    Authoritative structured output contract of Agent 3.
    
    Guardrails enforced:
    - priorityScore is bounded deterministically to [0, 100].
    - priority tier is an authoritative PriorityLevel enum.
    - requiredCrewType is an authoritative CrewType enum.
    - priorityReasons contains clear, evidence-based bullet points.
    - recommendationReason explains the crew assignment or constraint.
    """
    problem_id: str = Field(
        default="NEW_PROBLEM",
        alias="problemId",
        description="UUID of the municipal problem or 'NEW_PROBLEM'",
    )
    priority: PriorityLevel = Field(
        ...,
        description="Assessed priority tier: CRITICAL, HIGH, MEDIUM, or LOW",
    )
    priority_score: int = Field(
        ...,
        ge=0,
        le=100,
        alias="priorityScore",
        description="Normalized priority score between 0 and 100",
    )
    priority_reasons: list[str] = Field(
        ...,
        min_length=1,
        alias="priorityReasons",
        description="List of concise, observable criteria supporting the priority assessment",
    )
    required_crew_type: CrewType = Field(
        ...,
        alias="requiredCrewType",
        description="Specialized municipal crew type required for this issue",
    )
    recommended_crew_id: str = Field(
        ...,
        alias="recommendedCrewId",
        description="UUID of the recommended available crew or 'NONE' if no crew is available",
    )
    recommended_crew_name: str | None = Field(
        default=None,
        alias="recommendedCrewName",
        description="Human-readable name of the recommended crew",
    )
    recommendation_reason: str = Field(
        ...,
        min_length=10,
        alias="recommendationReason",
        description="Concise factual explanation of the crew selection or availability constraint",
    )

    model_config = {"populate_by_name": True, "serialize_by_alias": True}
