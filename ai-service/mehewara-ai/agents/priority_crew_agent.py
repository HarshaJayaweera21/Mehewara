"""
Mehewara AI Service — Agent 3: Priority & Crew Recommendation Agent

Implements Agent 3 in compliance with the Member 3 specification and SE3090 marking rubric (§9.1):
- Core Question: "How important is this municipal problem, and which specialized crew should handle it?"
- Scope: Assess defect severity/impact, assign priority tier & score (0-100), and recommend an available crew.
- Tool Integration: Uses 3 allow-listed tools (get_crew_capabilities, check_crew_availability, get_recent_jobs).
- Architectural Pattern: Follows ADR-04 (Deterministic tool execution + structured Pydantic output).
- Passthrough Schema: Follows ADR-05 (Consumes Agent 1's facts directly from Agent 2's output).
- Output: Strictly typed PriorityRecommendationOutput.
"""

from __future__ import annotations

import json
import logging
from typing import Any
from uuid import UUID

from langchain_core.messages import HumanMessage, SystemMessage

from app.config import settings
from app.llm import get_llm, is_llm_configured
from schemas.priority_recommendation import (
    CrewType,
    PriorityLevel,
    PriorityRecommendationInput,
    PriorityRecommendationOutput,
)
from tools.crew_tools import (
    AGENT_3_TOOLS,
    check_crew_availability,
    get_crew_capabilities,
    get_recent_jobs,
    reset_workflow_crew_context,
    set_workflow_crew_context,
)

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────
# Agent 3 System Prompt
# ────────────────────────────────────────────────────────────────

AGENT_3_SYSTEM_PROMPT = """You are Agent 3 (Priority & Crew Recommendation Agent) for the Mehewara Municipal Works Management System.

### YOUR ROLE & RESPONSIBILITY
Your SOLE responsibility is to evaluate the severity and urgency of consolidated municipal problems and recommend the optimal available municipal crew for dispatch.
Core Question: "How important is this municipal problem, and which specialized crew should handle it?"

### EVALUATION CRITERIA & SCORING GUIDELINES (0–100)
Determine the priority tier and an exact integer score between 0 and 100 based on the following factors:

1. **CRITICAL (Score: 85–100)**:
   - Immediate threat to life, public safety, or critical municipal infrastructure.
   - Examples: Live electrical wire sparking in flooded streets, collapsed bridge/culvert, main arterial road completely submerged/impassable, hospital/emergency vehicle access completely blocked, severe structural collapse.

2. **HIGH (Score: 60–84)**:
   - Significant hazard, substantial traffic obstruction, multiple resident reports, or compounding defect.
   - Examples: Overflowing roadside drain flooding commercial/school zone, major road lane blocked during peak hours, extensive streetlight failure along dark transit corridor, heavy tree branch hanging precariously over roadway.

3. **MEDIUM (Score: 30–59)**:
   - Moderate localized defect, limited traffic or nuisance impact, no immediate threat to life.
   - Examples: Deep pothole on secondary/residential road, illegal waste dump site emitting foul odor, clogged pedestrian sidewalk grating, damaged speed breaker.

4. **LOW (Score: 0–29)**:
   - Minor cosmetic or routine maintenance issue, single report, isolated defect with negligible safety impact.
   - Examples: Faded road surface markings, small non-structural curb chip, minor roadside litter, single non-critical streetlight out on well-lit street.

### MUNICIPAL CREW SPECIALIZATION MAPPING
Match the problem category to the authoritative municipal crew type:
- DRAINAGE: Stormwater flooding, blocked side drains, culvert siltation, canal overflows, manhole blockages.
- ROAD: Potholes, asphalt cracks, curb damage, road cave-in, pavement defect, guardrail repair.
- WASTE: Uncollected garbage, overflowing communal bins, illegal dumping sites, public waste clearance.
- ELECTRICAL: Streetlight failure, damaged distribution poles, hanging or sparking wires, traffic signals.
- ENVIRONMENT: Fallen trees/branches, public park maintenance, hazardous overgrown vegetation, landscaping.

### DISPATCH & AVAILABILITY RULES
1. You MUST examine the provided AVAILABLE CREWS list.
2. If an AVAILABLE crew of the matching required crew type exists:
   - Set `requiredCrewType` to that category.
   - Set `recommendedCrewId` to that crew's UUID.
   - Set `recommendedCrewName` to that crew's name.
   - In `recommendationReason`, clearly explain why this crew was chosen based on specialization and availability.
3. If all matching crews are BUSY or none are available:
   - Set `requiredCrewType` to the required category.
   - Set `recommendedCrewId` to "NONE" (or note the busy crew ID if deferral is recommended).
   - In `recommendationReason`, explicitly state that the matching crew is currently BUSY on an active work order and dispatch must be prioritized or queued by the coordinator.
4. Output MUST be an evidence-based, strictly formatted JSON object matching the PriorityRecommendationOutput schema.
"""


def _generate_deterministic_fallback(
    problem_data: dict[str, Any],
    structured_report: dict[str, Any] | None,
    available_crews: list[dict[str, Any]],
) -> PriorityRecommendationOutput:
    """
    Deterministic rule-based fallback for offline testing or when the LLM is unconfigured.
    Guarantees reliable assessment without network or quota dependencies.
    """
    cat_str = str(problem_data.get("category", "ROAD")).strip().upper()
    try:
        crew_type = CrewType(cat_str)
    except ValueError:
        crew_type = CrewType.ROAD

    text_to_scan = " ".join([
        str(problem_data.get("title", "")),
        str(problem_data.get("description", "")),
        json.dumps(structured_report or {}, default=str),
    ]).lower()

    report_count = int(problem_data.get("reportCount", 1))

    # Evaluate priority tier
    if any(k in text_to_scan for k in ["sparking", "live wire", "floodwater", "collapse", "hospital", "burst water main", "life-threatening"]):
        priority = PriorityLevel.CRITICAL
        score = 90
        reasons = [
            "Severe public safety risk requiring immediate emergency municipal intervention.",
            "Potential hazard to life or critical municipal infrastructure.",
        ]
    elif any(k in text_to_scan for k in ["overflow", "blocked drain", "flooding", "transit corridor", "arterial road", "emergency", "dark", "school zone"]) or report_count >= 3:
        priority = PriorityLevel.HIGH
        score = 75
        reasons = [
            f"Significant traffic or municipal obstruction reported across {report_count} citizen report(s).",
            "Compounding infrastructure impact requiring timely dispatch.",
        ]
    elif any(k in text_to_scan for k in ["pothole", "dump", "garbage", "waste", "odor", "crater"]):
        priority = PriorityLevel.MEDIUM
        score = 45
        reasons = [
            "Localized infrastructure defect causing moderate inconvenience.",
            "No immediate life-safety hazard detected.",
        ]
    else:
        priority = PriorityLevel.LOW
        score = 20
        reasons = [
            "Minor or routine maintenance issue with minimal community impact.",
        ]

    # Find matching available crew
    matching_crews = [
        c for c in available_crews
        if str(c.get("crewType", "")).upper() == crew_type.value
    ]
    available_matching = [
        c for c in matching_crews
        if str(c.get("status", "")).upper() == "AVAILABLE" and c.get("activeWorkOrderId") is None
    ]

    prob_id = str(problem_data.get("problemId") or problem_data.get("problem_id") or "NEW_PROBLEM")

    if available_matching:
        chosen = available_matching[0]
        crew_id = str(chosen.get("crewId") or chosen.get("id") or "")
        crew_name = str(chosen.get("name") or chosen.get("crewName") or f"{crew_type.value} Crew")
        reason = f"Specialized {crew_type.value} unit '{crew_name}' is currently AVAILABLE with zero active work orders."
    elif matching_crews:
        chosen = matching_crews[0]
        crew_id = str(chosen.get("crewId") or chosen.get("id") or "")
        crew_name = str(chosen.get("name") or chosen.get("crewName") or f"{crew_type.value} Crew")
        active_wo = chosen.get("activeWorkOrderId")
        reason = f"Specialized unit '{crew_name}' matches {crew_type.value} requirement, but is currently BUSY on active work order '{active_wo}'."
    else:
        crew_id = "NONE"
        crew_name = None
        reason = f"No registered municipal crews found matching specialty {crew_type.value}. Coordinator intervention required."

    return PriorityRecommendationOutput(
        problem_id=prob_id,
        priority=priority,
        priority_score=score,
        priority_reasons=reasons,
        required_crew_type=crew_type,
        recommended_crew_id=crew_id,
        recommended_crew_name=crew_name,
        recommendation_reason=reason,
    )


async def run_priority_recommendation(
    problem_data: dict[str, Any],
    structured_report: dict[str, Any] | None,
    available_crews: list[dict[str, Any]],
) -> PriorityRecommendationOutput:
    """
    Execute Agent 3 priority & crew recommendation.

    ADR-04 Pattern:
    1. Deterministically invoke allow-listed tools to gather crew context.
    2. Inject tool outputs directly into the LLM prompt.
    3. Request structured Pydantic output.
    """
    # 1. Set crew context for allow-listed tools in coroutine-isolated ContextVar
    token = set_workflow_crew_context(available_crews)
    try:
        # 2. Deterministically invoke tools to gather context (in-memory, ZERO SQL)
        all_crews = get_crew_capabilities.invoke({})
        required_cat = str(problem_data.get("category", "")).strip().upper()
        matching_available = check_crew_availability.invoke({"crew_type": required_cat})

        # Check workloads for matching crews
        crew_workloads: list[dict[str, Any]] = []
        for c in all_crews:
            cid = c.get("crewId")
            if cid:
                jobs = get_recent_jobs.invoke({"crew_id": cid})
                if jobs:
                    crew_workloads.extend(jobs)

        # If LLM is not configured, execute deterministic fallback
        if not is_llm_configured():
            logger.info("LLM not configured for Agent 3; executing deterministic fallback.")
            return _generate_deterministic_fallback(problem_data, structured_report, all_crews)

        # 3. Construct user prompt with problem, Agent 1 facts, and tool outputs
        prob_id = str(problem_data.get("problemId") or problem_data.get("problem_id") or "NEW_PROBLEM")
        user_prompt = f"""Please assess the priority and recommend an available crew for this municipal problem:

--- CONSOLIDATED MUNICIPAL PROBLEM ---
Problem ID: {prob_id}
Title: {problem_data.get('title', 'N/A')}
Description: {problem_data.get('description', 'N/A')}
Category: {required_cat}
Coordinates: ({problem_data.get('latitude', 0.0)}, {problem_data.get('longitude', 0.0)})
Address: {problem_data.get('address', 'N/A')}
Report Count: {problem_data.get('reportCount', 1)}

--- OBSERVABLE REPORT FACTS (Agent 1 Passthrough) ---
{json.dumps(structured_report, indent=2, default=str) if structured_report else 'No structured report facts available.'}

--- ALL REGISTERED CREWS IN SYSTEM ({len(all_crews)}) ---
{json.dumps(all_crews, indent=2, default=str)}

--- AVAILABLE CREWS MATCHING CATEGORY '{required_cat}' ({len(matching_available)}) ---
{json.dumps(matching_available, indent=2, default=str) if matching_available else 'None currently AVAILABLE.'}

--- ACTIVE WORK ORDER WORKLOADS ---
{json.dumps(crew_workloads, indent=2, default=str) if crew_workloads else 'No active work order workloads detected.'}

Evaluate the severity, assign priority tier (CRITICAL/HIGH/MEDIUM/LOW) with score (0-100), and recommend an available crew.
Return your response conforming to the PriorityRecommendationOutput schema.
"""

        try:
            llm = get_llm()
            structured_llm = llm.with_structured_output(PriorityRecommendationOutput)

            result = await structured_llm.ainvoke([
                SystemMessage(content=AGENT_3_SYSTEM_PROMPT),
                HumanMessage(content=user_prompt),
            ])

            if isinstance(result, PriorityRecommendationOutput):
                result.problem_id = prob_id
                # Enrich recommended_crew_name if missing
                if not result.recommended_crew_name and result.recommended_crew_id:
                    for c in all_crews:
                        if str(c.get("crewId")).lower() == str(result.recommended_crew_id).lower():
                            result.recommended_crew_name = c.get("name")
                            break
                return result

            if isinstance(result, dict):
                result["problemId"] = prob_id
                parsed = PriorityRecommendationOutput(**result)
                if not parsed.recommended_crew_name and parsed.recommended_crew_id:
                    for c in all_crews:
                        if str(c.get("crewId")).lower() == str(parsed.recommended_crew_id).lower():
                            parsed.recommended_crew_name = c.get("name")
                            break
                return parsed

            logger.warning("Agent 3 returned unexpected type %s; falling back to deterministic calculation.", type(result))
            return _generate_deterministic_fallback(problem_data, structured_report, all_crews)

        except Exception as ex:
            logger.exception("Agent 3 LLM invocation failed: %s; using deterministic fallback.", ex)
            return _generate_deterministic_fallback(problem_data, structured_report, all_crews)
    finally:
        reset_workflow_crew_context(token)
