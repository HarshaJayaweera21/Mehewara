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
import math
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


@tool
def calculate_crew_proximity(
    crew_lat: float,
    crew_lon: float,
    problem_lat: float,
    problem_lon: float,
) -> dict[str, Any]:
    """
    Calculate estimated road transit distance and travel time between crew coordinates and problem coordinates.
    Applies urban grid tortuosity factor (1.35) and average urban response speed (25 km/h).

    Args:
        crew_lat: Latitude of crew depot or current location.
        crew_lon: Longitude of crew depot or current location.
        problem_lat: Latitude of municipal problem.
        problem_lon: Longitude of municipal problem.
    """
    R = 6371.0  # Earth radius in km
    d_lat = math.radians(problem_lat - crew_lat)
    d_lon = math.radians(problem_lon - crew_lon)
    lat1 = math.radians(crew_lat)
    lat2 = math.radians(problem_lat)

    a = math.sin(d_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(d_lon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    straight_distance = R * c

    road_distance = round(straight_distance * 1.35, 2)
    travel_time_minutes = max(2, int(round((road_distance / 25.0) * 60)))

    return {
        "straightDistanceKm": round(straight_distance, 2),
        "roadDistanceKm": road_distance,
        "estimatedTravelMinutes": travel_time_minutes,
    }


@tool
def estimate_remediation_duration(
    category: str,
    priority: str = "MEDIUM",
    report_count: int = 1,
) -> dict[str, Any]:
    """
    Estimate physical on-site remediation duration in minutes based on municipal category, severity, and report volume.

    Args:
        category: Municipal category (DRAINAGE, ROAD, WASTE, ELECTRICAL, ENVIRONMENT).
        priority: Assessed priority level (LOW, MEDIUM, HIGH, CRITICAL).
        report_count: Number of citizen reports linked to the problem.
    """
    base_durations = {
        "WASTE": 35,
        "ELECTRICAL": 45,
        "DRAINAGE": 60,
        "ROAD": 75,
        "ENVIRONMENT": 60,
    }
    cat_upper = (category or "").strip().upper()
    base = base_durations.get(cat_upper, 60)

    prio_multipliers = {
        "LOW": 0.8,
        "MEDIUM": 1.0,
        "HIGH": 1.4,
        "CRITICAL": 2.0,
    }
    prio_upper = (priority or "MEDIUM").strip().upper()
    prio_mult = prio_multipliers.get(prio_upper, 1.0)

    vol_mult = min(1.5, 1.0 + 0.1 * max(0, report_count - 1))

    duration = int(round(base * prio_mult * vol_mult))
    clamped = max(15, min(480, duration))
    is_quick_win = clamped <= 45

    return {
        "category": cat_upper,
        "estimatedDurationMinutes": clamped,
        "isQuickWin": is_quick_win,
    }


AGENT_3_TOOLS = [
    get_crew_capabilities,
    check_crew_availability,
    get_recent_jobs,
    calculate_crew_proximity,
    estimate_remediation_duration,
]


