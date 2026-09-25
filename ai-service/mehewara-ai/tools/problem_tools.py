"""
Mehewara AI Service — Allow-Listed Tools for Agent 2 (Problem Consolidation)

Provides 5 least-privilege read-only candidate retrieval tools decorated with LangChain `@tool`:
1. search_existing_problems
2. search_similar_reports
3. get_problem_details
4. get_report_details
5. get_nearby_reports
"""

from __future__ import annotations

import math
from typing import Any
from uuid import UUID

from langchain_core.tools import tool


def calculate_haversine_distance_meters(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Calculate great-circle distance between two GPS coordinates in meters."""
    R = 6371000  # Radius of Earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 1)


# Global in-memory candidate store for workflow context & offline execution
_WORKFLOW_CANDIDATE_PROBLEMS: list[dict[str, Any]] = []
_WORKFLOW_RELATED_REPORTS: list[dict[str, Any]] = []


def set_workflow_candidate_context(
    candidate_problems: list[dict[str, Any]],
    related_reports: list[dict[str, Any]],
) -> None:
    """Populate candidate records supplied by ASP.NET Core for the active workflow."""
    global _WORKFLOW_CANDIDATE_PROBLEMS, _WORKFLOW_RELATED_REPORTS
    _WORKFLOW_CANDIDATE_PROBLEMS = candidate_problems
    _WORKFLOW_RELATED_REPORTS = related_reports


@tool
def search_existing_problems(
    category: str,
    latitude: float,
    longitude: float,
    radius_meters: float = 250.0,
) -> list[dict[str, Any]]:
    """Search for existing municipal problems in the database matching the category and proximity.
    
    Use this tool to find candidate Problems that the incoming report might belong to.
    
    Args:
        category: Municipal category ('ROAD', 'DRAINAGE', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT').
        latitude: Geographic latitude coordinate (-90 to 90).
        longitude: Geographic longitude coordinate (-180 to 180).
        radius_meters: Search radius in meters (default 250m).
    """
    cat_upper = category.upper()
    matches: list[dict[str, Any]] = []

    for prob in _WORKFLOW_CANDIDATE_PROBLEMS:
        prob_cat = str(prob.get("category", "")).upper()
        prob_lat = float(prob.get("latitude", 0.0))
        prob_lng = float(prob.get("longitude", 0.0))

        dist = calculate_haversine_distance_meters(latitude, longitude, prob_lat, prob_lng)

        # Match category and proximity threshold
        if prob_cat == cat_upper and dist <= radius_meters:
            item = dict(prob)
            item["distanceMeters"] = dist
            matches.append(item)

    # Sort by closest first
    matches.sort(key=lambda p: p.get("distanceMeters", 999999))
    return matches


@tool
def search_similar_reports(
    category: str,
    latitude: float,
    longitude: float,
    observed_issue: str,
    radius_meters: float = 200.0,
) -> list[dict[str, Any]]:
    """Search for previous resident reports that describe the same issue in the same area.
    
    Args:
        category: Municipal category.
        latitude: Geographic latitude coordinate.
        longitude: Geographic longitude coordinate.
        observed_issue: Description of observable issue to check similarity against.
        radius_meters: Search radius in meters (default 200m).
    """
    cat_upper = category.upper()
    issue_words = set(observed_issue.lower().split())
    matches: list[dict[str, Any]] = []

    for rep in _WORKFLOW_RELATED_REPORTS:
        rep_cat = str(rep.get("category", "")).upper()
        rep_lat = float(rep.get("latitude", 0.0))
        rep_lng = float(rep.get("longitude", 0.0))

        dist = calculate_haversine_distance_meters(latitude, longitude, rep_lat, rep_lng)

        if rep_cat == cat_upper and dist <= radius_meters:
            rep_desc = str(rep.get("description", "")).lower()
            rep_words = set(rep_desc.split())
            overlap = len(issue_words.intersection(rep_words))

            item = dict(rep)
            item["distanceMeters"] = dist
            item["keywordOverlapCount"] = overlap
            matches.append(item)

    matches.sort(key=lambda r: (r.get("distanceMeters", 999999), -r.get("keywordOverlapCount", 0)))
    return matches


@tool
def get_problem_details(problem_id: str) -> dict[str, Any]:
    """Retrieve full details of an existing Problem by UUID.
    
    Args:
        problem_id: String UUID of the Problem.
    """
    for prob in _WORKFLOW_CANDIDATE_PROBLEMS:
        pid = str(prob.get("problemId") or prob.get("id") or "")
        if pid == str(problem_id):
            return prob

    return {
        "problemId": problem_id,
        "found": False,
        "message": f"Problem {problem_id} not found in active municipal candidates.",
    }


@tool
def get_report_details(report_id: str) -> dict[str, Any]:
    """Retrieve full details of a specific resident report by UUID.
    
    Args:
        report_id: String UUID of the Report.
    """
    for rep in _WORKFLOW_RELATED_REPORTS:
        rid = str(rep.get("reportId") or rep.get("id") or "")
        if rid == str(report_id):
            return rep

    return {
        "reportId": report_id,
        "found": False,
        "message": f"Report {report_id} not found in active report candidates.",
    }


@tool
def get_nearby_reports(
    latitude: float,
    longitude: float,
    radius_meters: float = 150.0,
    category: str | None = None,
) -> list[dict[str, Any]]:
    """Retrieve all reports geographically close to a coordinate, optionally filtered by category.
    
    Args:
        latitude: Geographic latitude coordinate.
        longitude: Geographic longitude coordinate.
        radius_meters: Search radius in meters (default 150m).
        category: Optional category filter.
    """
    nearby: list[dict[str, Any]] = []
    cat_filter = category.upper() if category else None

    for rep in _WORKFLOW_RELATED_REPORTS:
        rep_lat = float(rep.get("latitude", 0.0))
        rep_lng = float(rep.get("longitude", 0.0))
        dist = calculate_haversine_distance_meters(latitude, longitude, rep_lat, rep_lng)

        if dist <= radius_meters:
            rep_cat = str(rep.get("category", "")).upper()
            if cat_filter is None or rep_cat == cat_filter:
                item = dict(rep)
                item["distanceMeters"] = dist
                nearby.append(item)

    nearby.sort(key=lambda r: r.get("distanceMeters", 999999))
    return nearby


AGENT_2_TOOLS = [
    search_existing_problems,
    search_similar_reports,
    get_problem_details,
    get_report_details,
    get_nearby_reports,
]
