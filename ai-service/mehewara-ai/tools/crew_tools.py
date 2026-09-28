"""
Mehewara AI Service — Allow-Listed Tools for Agent 3 (Priority & Crew Recommendation)

Provides 3 least-privilege read-only tools decorated with LangChain `@tool`:
1. get_crew_capabilities: Discovers all registered crews and their specialization.
2. check_crew_availability: Filters currently available crews by municipal category.
3. get_recent_jobs: Inspects active work order backlog for a specific crew.

CRUCIAL ARCHITECTURAL CONSTRAINTS (ADR-04 & ZERO-DB):
- FastAPI has NO direct PostgreSQL connection (no database drivers, no credentials).
- These tools NEVER execute direct SQL queries or open network database connections.
- They operate strictly in-memory against state["available_crews"] injected by ASP.NET Core's AiWorkflowClient.cs.
- In-memory state is isolated per coroutine using Python contextvars to guarantee thread/task concurrency safety.
- Tools are invoked deterministically per ADR-04 with outputs injected into prompt context (NO dynamic tool binding).
"""

from __future__ import annotations

import contextvars
import logging
from typing import Any
from langchain_core.tools import tool

logger = logging.getLogger(__name__)

# Coroutine-isolated context variable (thread-safe and async-task-safe)
_workflow_crews_ctx: contextvars.ContextVar[list[dict[str, Any]]] = contextvars.ContextVar(
    "workflow_available_crews",
    default=[],
)


def set_workflow_crew_context(available_crews: list[dict[str, Any]]) -> contextvars.Token:
    """
    Populate the real-time crew context passed from ASP.NET Core for the active workflow run.
    Stores the collection in a coroutine-isolated ContextVar and returns a reset token.
    """
    crews = list(available_crews or [])
    token = _workflow_crews_ctx.set(crews)
    logger.info("Agent 3 crew context loaded: %d crews registered in context.", len(crews))
    return token


def reset_workflow_crew_context(token: contextvars.Token) -> None:
    """
    Reset the coroutine-isolated crew context back to its previous state.
    """
    try:
        _workflow_crews_ctx.reset(token)
    except Exception as ex:
        logger.warning("Failed to reset crew context token: %s", ex)


def get_current_workflow_crews() -> list[dict[str, Any]]:
    """
    Retrieve the current workflow's crew list from the active coroutine ContextVar.
    Operates strictly in memory; zero database queries.
    """
    return _workflow_crews_ctx.get()


@tool
def get_crew_capabilities() -> list[dict[str, Any]]:
    """
    Get all registered municipal crews with their specialization, current status, and crew ID.
    Used by Agent 3 to evaluate the full municipal workforce capacity.
    Operates strictly in memory against injected workflow state (ZERO SQL).
    """
    crews = get_current_workflow_crews()
    capabilities: list[dict[str, Any]] = []

    for c in crews:
        crew_id = str(c.get("crewId") or c.get("crew_id") or c.get("id") or "").strip()
        crew_name = str(c.get("name") or c.get("crewName") or c.get("crew_name") or "Unknown Crew").strip()
        crew_type = str(c.get("crewType") or c.get("crew_type") or "").strip().upper()
        status = str(c.get("status") or "").strip().upper()
        active_wo = c.get("activeWorkOrderId") or c.get("active_work_order_id")

        capabilities.append({
            "crewId": crew_id,
            "name": crew_name,
            "crewType": crew_type,
            "status": status,
            "activeWorkOrderId": str(active_wo) if active_wo else None,
        })

    return capabilities


@tool
def check_crew_availability(crew_type: str | None = None) -> list[dict[str, Any]]:
    """
    Check which municipal crews are currently AVAILABLE (not occupied by an active work order).
    Operates strictly in memory against injected workflow state (ZERO SQL).
    
    Args:
        crew_type: Optional municipal category filter (DRAINAGE, ROAD, WASTE, ELECTRICAL, ENVIRONMENT).
    """
    all_crews = get_crew_capabilities.invoke({})
    cat_filter = crew_type.strip().upper() if crew_type else None

    available: list[dict[str, Any]] = []
    for c in all_crews:
        if c.get("status") == "AVAILABLE" and c.get("activeWorkOrderId") is None:
            if cat_filter is None or c.get("crewType") == cat_filter:
                available.append(c)

    return available


@tool
def get_recent_jobs(crew_id: str) -> list[dict[str, Any]]:
    """
    Get the active work order workload for a specific municipal crew to assess current backlog.
    Operates strictly in memory using activeWorkOrderId supplied by ASP.NET Core (ZERO SQL).
    
    Args:
        crew_id: The UUID string of the crew to inspect.
    """
    cid_str = str(crew_id).strip().lower()
    crews = get_current_workflow_crews()
    for c in crews:
        current_id = str(c.get("crewId") or c.get("crew_id") or c.get("id") or "").strip().lower()
        if current_id == cid_str:
            active_wo = c.get("activeWorkOrderId") or c.get("active_work_order_id")
            if active_wo:
                return [
                    {
                        "workOrderId": str(active_wo),
                        "status": "IN_PROGRESS",
                        "crewId": current_id,
                    }
                ]
            return []
    return []


AGENT_3_TOOLS = [
    get_crew_capabilities,
    check_crew_availability,
    get_recent_jobs,
]

