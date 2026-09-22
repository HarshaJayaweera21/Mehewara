"""
Mehewara AI Service — API Routes

Defines the FastAPI router with:
- GET  /internal/ai/health     → service healthcheck
- POST /internal/ai/workflows  → workflow trigger endpoint (executes Agent 1)
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException

from api.models import (
    HealthResponse,
    WorkflowTriggerRequest,
    WorkflowTriggerResponse,
)
from app.config import settings
from app.llm import is_llm_configured
from workflow.report_workflow import run_report_analysis_workflow

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/internal/ai", tags=["AI Workflows"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Service healthcheck endpoint.

    Returns service status, version, environment, and whether the LLM is configured.
    Called by ASP.NET Core backend to verify AI service availability.
    """
    return HealthResponse(
        status="healthy",
        service="mehewara-ai",
        version="0.1.0",
        environment=settings.environment,
        llm_configured=is_llm_configured(),
    )


@router.post("/workflows", response_model=WorkflowTriggerResponse)
async def trigger_workflow(request: WorkflowTriggerRequest) -> WorkflowTriggerResponse:
    """
    Receive a workflow trigger from the ASP.NET Core backend and execute Agent 1.

    Extracts evidence-grounded facts, maps municipal assets, checks for omissions,
    and returns a structured report schema without speculating on unobserved root causes.
    """
    logger.info(
        "Executing Agent 1 analysis for Workflow %s (Report %s, Reported Category: %s)",
        request.workflow_id,
        request.report.id,
        request.report.category,
    )

    try:
        raw_report_dict = request.report.model_dump(by_alias=True)
        structured_report = await run_report_analysis_workflow(raw_report_dict)

        logger.info(
            "Agent 1 analysis completed: Report %s -> Inferred Category: %s (Confidence: %.2f)",
            request.report.id,
            structured_report.inferred_category.value,
            structured_report.category_confidence,
        )

        return WorkflowTriggerResponse(
            workflow_id=request.workflow_id,
            status="completed",
            message=f"Agent 1 report analysis completed for report {request.report.id}",
            analysis=structured_report,
        )

    except Exception as ex:
        logger.exception("Error executing Agent 1 workflow: %s", ex)
        raise HTTPException(
            status_code=500,
            detail=f"Agent 1 processing failed: {ex}",
        )
