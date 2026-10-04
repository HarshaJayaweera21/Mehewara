"""Agent 4 can only retrieve evidence through this read-only backend operation."""
import asyncio
import httpx
from langchain_core.tools import tool
from app.config import settings


@tool
async def get_validation_context(workflow_id: str, report_ids: list[str],
                                 problem_id: str | None = None, crew_id: str | None = None,
                                 job_id: str | None = None) -> dict:
    """Retrieve workflow-authorized evidence, completeness and active-work information."""
    if not settings.internal_ai_api_key:
        raise RuntimeError("Internal service authentication is not configured")
    async with asyncio.timeout(settings.agent4_evidence_timeout_seconds):
        async with httpx.AsyncClient(timeout=settings.agent4_evidence_timeout_seconds) as client:
            response = await client.post(
                settings.dotnet_api_base_url.rstrip("/") + "/internal/ai/validation-context",
                headers={"X-Internal-Api-Key": settings.internal_ai_api_key},
                json={"workflowId": workflow_id, "jobId": job_id, "problemId": problem_id,
                      "reportIds": report_ids, "crewId": crew_id},
            )
            response.raise_for_status()
            return response.json()
