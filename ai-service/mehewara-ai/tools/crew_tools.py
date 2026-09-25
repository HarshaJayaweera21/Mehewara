"""
Mehewara AI Service — Allow-Listed Tools for Agent 3 (Priority & Crew Recommendation)

Provides 3 least-privilege read-only tools decorated with LangChain `@tool`:
1. get_crew_capabilities: Discovers all registered crews and their specialization.
2. check_crew_availability: Filters currently available crews by municipal category.
3. get_recent_jobs: Inspects active work order backlog for a specific crew.

Invoked deterministically per ADR-04 with outputs injected into prompt context.
"""

from __future__ import annotations

import logging
from typing import Any
from langchain_core.tools import tool

logger = logging.getLogger(__name__)

# Module-level context set by the workflow node before tool execution
_WORKFLOW_AVAILABLE_CREWS: list[dict[str, Any]] = []


def set_workflow_crew_context(available_crews: list[dict[str, Any]]) -> None:
    """
    Populate the real-time crew context passed from ASP.NET Core for the active workflow run.
    """
    global _WORKFLOW_AVAILABLE_CREWS
    _WORKFLOW_AVAILABLE_CREWS = available_crews or []
    logger.info("Agent 3 crew context loaded: %d crews registered in state.", len(_WORKFLOW_AVAILABLE_CREWS))


@tool
def get_crew_capabilities() -> list[dict[str, Any]]:
    """
    Get all registered municipal crews with their specialization, current status, and crew ID.
    Used by Agent 3 to evaluate the full municipal workforce capacity.
    """
    return [
        {
            "crewId": str(c.get("crewId") or c.get("id") or ""),
            "name": c.get("name") or c.get("crewName") or "Unknown Crew",
            "crewType": str(c.get("crewType") or "").upper(),
            "status": str(c.get("status") or "").upper(),
            "activeWorkOrderId": c.get("activeWorkOrderId"),
        }
        for c in _WORKFLOW_AVAILABLE_CREWS
    ]


@tool
def check_crew_availability(crew_type: str | None = None) -> list[dict[str, Any]]:
    """
    Check which municipal crews are currently AVAILABLE (not occupied by an active work order).
    
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
    
    Args:
        crew_id: The UUID string of the crew to inspect.
    """
    cid_str = str(crew_id).strip().lower()
    for c in _WORKFLOW_AVAILABLE_CREWS:
        current_id = str(c.get("crewId") or c.get("id") or "").lower()
        if current_id == cid_str:
            active_wo = c.get("activeWorkOrderId")
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
