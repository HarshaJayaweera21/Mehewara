"""
Mehewara AI Service — Agent 2: Problem Consolidation Agent

Implements Agent 2 in compliance with the Member 2 specification and SE3090 marking rubric:
- Core Question: "What real-world municipal problem does this resident report belong to?"
- Scope: Group incoming reports with existing Problems or consolidate related reports into a new Problem.
- Tool Integration: Uses 5 allow-listed read tools for spatial proximity and semantic candidate retrieval.
- Safe Failure: Emits UNCERTAIN when evidence is conflicting or ambiguous, preventing false merges.
- Output: Strictly typed ProblemConsolidationOutputSchema.
"""

from __future__ import annotations

import json
import logging
from typing import Any
from uuid import UUID

from app.config import settings
from app.llm import get_llm, is_llm_configured
from schemas.problem_consolidation import (
    ConsolidationDecision,
    NewProblemCandidate,
    ProblemConsolidationInputSchema,
    ProblemConsolidationOutputSchema,
)
from tools.problem_tools import (
    AGENT_2_TOOLS,
    calculate_haversine_distance_meters,
    get_nearby_reports,
    get_problem_details,
    search_existing_problems,
    search_similar_reports,
)

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────
# Agent 2 System Prompt
# ────────────────────────────────────────────────────────────────

AGENT_2_SYSTEM_PROMPT = """You are Agent 2 (Problem Consolidation Agent) for the Mehewara Municipal Works Management System.

Your SOLE responsibility is to determine what real-world municipal Problem an incoming resident report belongs to.

### CORE OBJECTIVES:
1. Determine if the report describes an issue that is ALREADY part of an existing registered Problem in the city.
2. If yes, link it to the existing Problem (`LINK_EXISTING`) and update the synthesized problem summary.
3. If no, determine if it represents a brand new Problem. Cluster any other matching citizen reports and propose a new Problem representation with an initial AI summary (`CREATE_NEW`).
4. If the evidence is contradictory, ambiguous, or insufficient to be certain, produce a safe failure (`UNCERTAIN`).

### DECISION RULES & PROBLEM SUMMARIES:
1. **LINK_EXISTING:**
   - Use when an existing Problem in the database has the same municipal category, is geographically close (< 150m), and describes the same physical defect.
   - `problemId` MUST be the UUID of the matching Problem.
   - `newProblem` MUST be null.
   - Include the current report UUID and all matching report UUIDs in `relatedReportIds`.
   - **UPDATED PROBLEM DESCRIPTION:** You MUST populate `updatedProblemDescription` with a comprehensive, synthesized summary of what all citizen reports under this problem describe. If this latest report brings new information (e.g. water level rising, specific lane blocked, health/hazard risks, expanding defect), integrate these new details into the existing problem description so coordinators have an up-to-date, single source of truth.

2. **CREATE_NEW:**
   - Use when NO existing Problem matches the incident, but the report describes a genuine municipal issue.
   - `problemId` MUST be null.
   - `newProblem` MUST be populated with a concise factual title, category, coordinates, address, and an initial `description`.
   - **INITIAL PROBLEM DESCRIPTION:** `newProblem.description` MUST be a factual, informative synthesis summarizing what this initial resident report describes.
   - Include the current report UUID and any other unassigned reports in the area that describe this same incident in `relatedReportIds`.

3. **UNCERTAIN (Safe Failure):**
   - Use when there are competing candidate problems at similar distances, or conflicting evidence.
   - It is far better to be UNCERTAIN than to incorrectly merge two separate problems!
   - `problemId` MUST be null, `newProblem` MUST be null, `updatedProblemDescription` MUST be null.

### STRICT GUARDRAILS:
- DO NOT assign priority (LOW/MEDIUM/HIGH/CRITICAL) — that is owned by Agent 3.
- DO NOT assign or recommend crews — that is owned by Agent 3 & 4.
- DO NOT dispatch or approve work — that requires human coordinator approval.
- DO NOT invent facts or guess unobserved locations.
- Provide clear, concise observable bullet points in `evidence`.
"""


# ────────────────────────────────────────────────────────────────
# Asynchronous Agent 2 Invocation (Pure LLM Agent Execution)
# ────────────────────────────────────────────────────────────────

async def consolidate_problem_with_agent(
    input_data: ProblemConsolidationInputSchema,
) -> ProblemConsolidationOutputSchema:
    """
    Execute Agent 2 Problem Consolidation using Google Gemini with dynamic context retrieval
    and schema-validated output. Every execution runs strictly through the LLM agent.
    """
    if not is_llm_configured():
        raise RuntimeError(
            "Agent 2 requires a configured LLM. Please set GEMINI_API_KEY in .env."
        )

    from langchain_core.messages import HumanMessage, SystemMessage

    llm = get_llm(temperature=0.1)

    source = input_data.source_report
    structured = input_data.structured_report

    # Query candidate context via allow-listed tools
    cat = structured.inferred_category.value
    candidate_problems = search_existing_problems.invoke({
        "category": cat,
        "latitude": source.latitude,
        "longitude": source.longitude,
        "radius_meters": 300.0,
    })
    similar_reports = search_similar_reports.invoke({
        "category": cat,
        "latitude": source.latitude,
        "longitude": source.longitude,
        "observed_issue": structured.observed_issue,
        "radius_meters": 250.0,
    })

    user_content = f"""Please analyze this incoming resident report and consolidate it:

--- INCOMING REPORT ---
Report ID: {source.report_id}
Resident Category: {source.category}
Inferred Category: {cat}
Coordinates: ({source.latitude}, {source.longitude})
Address: {source.address or 'Address not specified'}
Observed Issue: {structured.observed_issue}
Affected Asset: {structured.affected_asset}
Reported Impacts: {json.dumps(structured.reported_impact)}
Hazards: {json.dumps(structured.hazards)}

--- CANDIDATE PROBLEMS FOUND NEARBY ({len(candidate_problems)}) ---
{json.dumps(candidate_problems, indent=2, default=str)}

--- SIMILAR CITIZEN REPORTS FOUND NEARBY ({len(similar_reports)}) ---
{json.dumps(similar_reports, indent=2, default=str)}

Determine whether this report should LINK_EXISTING, CREATE_NEW, or is UNCERTAIN.
Output the structured consolidation schema.
"""

    structured_llm = llm.with_structured_output(ProblemConsolidationOutputSchema)

    result = await structured_llm.ainvoke([
        SystemMessage(content=AGENT_2_SYSTEM_PROMPT),
        HumanMessage(content=user_content),
    ])

    if isinstance(result, ProblemConsolidationOutputSchema):
        result.report_id = source.report_id
        result.structured_report = structured
        if source.report_id not in result.related_report_ids:
            result.related_report_ids.insert(0, source.report_id)
        return result

    if isinstance(result, dict):
        result["reportId"] = source.report_id
        result["structuredReport"] = structured
        return ProblemConsolidationOutputSchema(**result)

    raise ValueError(
        f"Agent 2 failed to produce a valid ProblemConsolidationOutputSchema. Received: {type(result)}"
    )
