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
from workflow.mehewara_workflow import (
    get_workflow_mermaid_diagram,
    run_mehewara_workflow,
)

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


@router.get("/workflows/diagram")
async def get_workflow_diagram() -> dict[str, str]:
    """
    Returns the Mermaid diagram of the compiled multi-agent LangGraph workflow.
    Useful for system documentation, architectural review, and viva evaluation.
    """
    return {
        "diagram": get_workflow_mermaid_diagram(),
    }


@router.post("/workflows", response_model=WorkflowTriggerResponse)
async def trigger_workflow(request: WorkflowTriggerRequest) -> WorkflowTriggerResponse:
    """
    Receive a workflow trigger from the ASP.NET Core backend and execute
    the unified LangGraph multi-agent pipeline (Agent 1 -> Agent 2 -> END).

    Stage 1 (Agent 1): Extracts evidence-grounded facts, maps municipal assets, checks omissions.
    Stage 2 (Agent 2): Clusters incoming report into existing Problems or generates a new Problem.
    """
    logger.info(
        "Executing unified Mehewara multi-agent workflow %s (Report %s, Reported Category: %s)",
        request.workflow_id,
        request.report.id,
        request.report.category,
    )

    try:
        raw_report_dict = request.report.model_dump(by_alias=True)
        candidate_problems = request.context.candidate_problems
        related_reports = request.context.related_reports
        available_crews = request.context.available_crews

        result = await run_mehewara_workflow(
            workflow_id=request.workflow_id,
            raw_report_dict=raw_report_dict,
            candidate_problems=candidate_problems,
            related_reports=related_reports,
            available_crews=available_crews,
        )

        report_analysis = result.get("report_analysis")
        problem_analysis = result.get("problem_analysis")

        logger.info(
            "Unified workflow %s completed successfully: Report %s",
            request.workflow_id,
            request.report.id,
        )

        return WorkflowTriggerResponse(
            workflow_id=request.workflow_id,
            status="completed",
            message=f"Unified multi-agent workflow completed for report {request.report.id}",
            report_analysis=report_analysis,
            problem_analysis=problem_analysis,
            analysis=report_analysis,
        )

    except Exception as ex:
        logger.exception("Error executing unified multi-agent workflow: %s", ex)
        raise HTTPException(
            status_code=500,
            detail=f"Unified multi-agent workflow processing failed: {ex}",
        )
