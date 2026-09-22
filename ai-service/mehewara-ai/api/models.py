"""
Mehewara AI Service — API Request & Response Models

These Pydantic models define the contract between the ASP.NET Core backend
and this FastAPI microservice. The request schema mirrors exactly what
`AiWorkflowClient.TriggerWorkflowAsync()` sends.
"""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field

from schemas.report_analysis import StructuredReport


# ────────────────────────────────────────────────────────────────
# Inbound models (from ASP.NET Core → FastAPI)
# ────────────────────────────────────────────────────────────────

class ReportPhotoPayload(BaseModel):
    """A single photo attached to a report."""
    photo_id: UUID = Field(..., alias="photoId")
    photo_url: str = Field(..., alias="photoUrl")
    file_name: str = Field(..., alias="fileName")
    mime_type: str = Field(..., alias="mimeType")

    model_config = {"populate_by_name": True}


class ReportPayload(BaseModel):
    """The report data sent from the .NET backend."""
    id: UUID
    description: str
    category: str
    latitude: float
    longitude: float
    address: str | None = None
    photos: list[ReportPhotoPayload] = Field(default_factory=list)

    model_config = {"populate_by_name": True}


class WorkflowContext(BaseModel):
    """Additional context provided alongside the report."""
    candidate_problems: list[dict] = Field(default_factory=list, alias="candidateProblems")
    related_reports: list[dict] = Field(default_factory=list, alias="relatedReports")
    available_crews: list[dict] = Field(default_factory=list, alias="availableCrews")

    model_config = {"populate_by_name": True}


class WorkflowTriggerRequest(BaseModel):
    """
    The top-level request body sent by AiWorkflowClient.TriggerWorkflowAsync().

    Maps directly to the JSON payload:
    {
        "workflowId": "<guid>",
        "report": { ... },
        "context": { ... }
    }
    """
    workflow_id: UUID = Field(..., alias="workflowId")
    report: ReportPayload
    context: WorkflowContext = Field(default_factory=WorkflowContext)

    model_config = {"populate_by_name": True}


# ────────────────────────────────────────────────────────────────
# Outbound models (FastAPI → ASP.NET Core)
# ────────────────────────────────────────────────────────────────

class WorkflowTriggerResponse(BaseModel):
    """Response returned after processing or queueing a workflow trigger."""
    status: str = "completed"
    workflow_id: UUID = Field(..., alias="workflowId")
    message: str = "Agent 1 report analysis completed successfully"
    analysis: StructuredReport | None = Field(
        default=None,
        description="Structured report analysis extracted by Agent 1",
    )

    model_config = {"populate_by_name": True, "serialize_by_alias": True}


class HealthResponse(BaseModel):
    """Healthcheck response."""
    status: str = "healthy"
    service: str = "mehewara-ai"
    version: str = "0.1.0"
    environment: str = "development"
    llm_configured: bool = False
