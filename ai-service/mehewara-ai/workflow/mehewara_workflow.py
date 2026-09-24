"""
Mehewara AI Service — Central Multi-Agent LangGraph Pipeline

Authoritative LangGraph orchestration pipeline for the Mehewara Municipal System.
Chains the 4 specialized agent stages sequentially:
- Node 1: Agent 1 (Report Analysis & Structuring) — Owner: Member 1
- Node 2: Agent 2 (Problem Consolidation)          — Owner: Member 2
- Node 3: Agent 3 (Prioritization & Crew)          — Owner: Member 3 (Plug-in ready)
- Node 4: Agent 4 (Validation & Safety)            — Owner: Member 4 (Plug-in ready)
"""

from __future__ import annotations

import logging
from typing import Any, TypedDict
from uuid import UUID

from langgraph.graph import END, StateGraph

# Agent 1 (Member 1)
from agents.report_agent import analyze_report_with_llm
from schemas.report_analysis import MunicipalCategory, ReportInputSchema, StructuredReport
from tools.report_tools import get_location_context, get_municipal_asset_catalog

# Agent 2 (Member 2)
from agents.problem_agent import consolidate_problem_with_agent
from schemas.problem_consolidation import (
    ProblemConsolidationInputSchema,
    ProblemConsolidationOutputSchema,
    SourceReportPayload,
)
from tools.problem_tools import set_workflow_candidate_context

# Agent 3 (Member 3)
from agents.priority_crew_agent import run_priority_recommendation
from schemas.priority_recommendation import PriorityRecommendationOutput
from tools.crew_tools import set_workflow_crew_context

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────
# 1. Unified Multi-Agent Workflow State
# ────────────────────────────────────────────────────────────────

class MehewaraWorkflowState(TypedDict, total=False):
    """
    Authoritative state flowing sequentially through all agent nodes.
    Each agent reads from this state and attaches its output dictionary.
    """
    workflow_id: str
    raw_report: dict[str, Any]

    # Context supplied from ASP.NET Core
    candidate_problems: list[dict[str, Any]]
    related_reports: list[dict[str, Any]]
    available_crews: list[dict[str, Any]]

    # Stage 1 Output (Member 1 — Report Analysis & Structuring)
    structured_report: dict[str, Any] | None
    report_analysis: dict[str, Any] | None

    # Stage 2 Output (Member 2 — Problem Identification & Consolidation)
    problem_analysis: dict[str, Any] | None

    # Stage 3 Output (Member 3 — Prioritization & Crew Recommendation)
    priority_analysis: dict[str, Any] | None
    recommendations: list[dict[str, Any]] | None

    # Stage 4 Output (Member 4 — Validation & Safety - Future)
    safety_validation: dict[str, Any] | None

    error: str | None


# ────────────────────────────────────────────────────────────────
# 2. Stage Nodes
# ────────────────────────────────────────────────────────────────

async def agent_1_report_analysis_node(state: MehewaraWorkflowState) -> dict[str, Any]:
    """
    Node 1: Agent 1 (Report Analysis & Structuring — Member 1)
    Gathers spatial context & asset catalogs, executes factual LLM extraction,
    and enforces Pydantic schema guardrails.
    """
    logger.info("[Workflow %s] Executing Node 1: Agent 1 (Report Analysis)...", state.get("workflow_id"))
    raw = state.get("raw_report", {})

    try:
        # 1. Ingest context via Member 1 allow-listed tools
        lat = raw.get("latitude", 0.0)
        lng = raw.get("longitude", 0.0)
        addr = raw.get("address")
        cat = raw.get("category")

        location_ctx = get_location_context.invoke({
            "latitude": lat,
            "longitude": lng,
            "address": addr,
        })
        assets = get_municipal_asset_catalog.invoke({
            "category": cat,
        })

        # 2. Execute Agent 1 factual extraction
        report_input = ReportInputSchema(**raw)
        structured: StructuredReport = await analyze_report_with_llm(report_input)

        # 3. Enforce schema guardrails
        assert structured.inferred_category in MunicipalCategory
        assert 0.0 <= structured.category_confidence <= 1.0

        logger.info(
            "[Workflow %s] Agent 1 completed successfully. Inferred Category: %s (Confidence: %.2f)",
            state.get("workflow_id"),
            structured.inferred_category.value,
            structured.category_confidence,
        )

        structured_dict = structured.model_dump(by_alias=True)
        return {
            "structured_report": structured_dict,
            "report_analysis": structured_dict,
        }
    except Exception as ex:
        logger.exception("[Workflow %s] Agent 1 execution failed: %s", state.get("workflow_id"), ex)
        return {"error": f"Agent 1 failed: {ex}"}


async def agent_2_problem_consolidation_node(state: MehewaraWorkflowState) -> dict[str, Any]:
    """
    Node 2: Agent 2 (Problem Identification & Consolidation — Member 2)
    Consolidates incoming report with existing municipal Problems or clusters into a new Problem.
    """
    logger.info("[Workflow %s] Executing Node 2: Agent 2 (Problem Consolidation)...", state.get("workflow_id"))
    structured_dict = state.get("structured_report")
    raw_report_dict = state.get("raw_report", {})

    if not structured_dict:
        logger.error("[Workflow %s] Cannot execute Agent 2: Missing Agent 1 output.", state.get("workflow_id"))
        return {"error": "Missing structured report from Agent 1"}

    try:
        # 1. Provide authorized candidate context to Agent 2 tools
        set_workflow_candidate_context(
            candidate_problems=state.get("candidate_problems", []),
            related_reports=state.get("related_reports", []),
        )

        # 2. Construct strict Agent 2 input schema
        structured_obj = StructuredReport(**structured_dict)
        source_obj = SourceReportPayload(
            reportId=raw_report_dict.get("id"),
            description=raw_report_dict.get("description", ""),
            category=raw_report_dict.get("category", ""),
            latitude=raw_report_dict.get("latitude", 0.0),
            longitude=raw_report_dict.get("longitude", 0.0),
            address=raw_report_dict.get("address"),
            createdAt=raw_report_dict.get("createdAt"),
        )

        agent_2_input = ProblemConsolidationInputSchema(
            structuredReport=structured_obj,
            sourceReport=source_obj,
        )

        # 3. Execute Agent 2 cognitive consolidation
        consolidation_result: ProblemConsolidationOutputSchema = await consolidate_problem_with_agent(agent_2_input)

        logger.info(
            "[Workflow %s] Agent 2 completed successfully. Decision: %s, Problem ID: %s",
            state.get("workflow_id"),
            consolidation_result.decision.value,
            consolidation_result.problem_id,
        )

        return {
            "problem_analysis": consolidation_result.model_dump(by_alias=True),
        }
    except Exception as ex:
        logger.exception("[Workflow %s] Agent 2 execution failed: %s", state.get("workflow_id"), ex)
        return {"error": f"Agent 2 failed: {ex}"}


async def agent_3_prioritization_node(state: MehewaraWorkflowState) -> dict[str, Any]:
    """
    Node 3: Agent 3 (Prioritization & Crew Recommendation — Member 3)
    Reads consolidated problem and Agent 1 facts from Agent 2's output,
    assesses problem severity/urgency, and recommends an available crew.
    """
    logger.info("[Workflow %s] Executing Node 3: Agent 3 (Prioritization & Crew Recommendation)...", state.get("workflow_id"))

    problem_analysis = state.get("problem_analysis")
    if not problem_analysis:
        logger.warning("[Workflow %s] No problem analysis from Agent 2; skipping Agent 3.", state.get("workflow_id"))
        return {
            "priority_analysis": None,
            "recommendations": [],
        }

    # Safe Failure check (ADR-06): If Agent 2 decision is UNCERTAIN, bypass prioritization
    decision = problem_analysis.get("decision")
    if decision == "UNCERTAIN":
        logger.info("[Workflow %s] Problem consolidation is UNCERTAIN; skipping Agent 3 prioritization pending coordinator review.", state.get("workflow_id"))
        return {
            "priority_analysis": None,
            "recommendations": [],
        }

    try:
        raw_rep = state.get("raw_report", {})
        new_prob = problem_analysis.get("newProblem") or {}

        # 1. Assemble problem data
        prob_id = problem_analysis.get("problemId") or "NEW_PROBLEM"
        prob_title = (
            new_prob.get("title")
            or problem_analysis.get("summary")
            or raw_rep.get("description", "Municipal Problem")
        )
        prob_desc = (
            problem_analysis.get("updatedProblemDescription")
            or new_prob.get("description")
            or raw_rep.get("description", "")
        )
        prob_cat = (
            new_prob.get("category")
            or raw_rep.get("category", "")
        )
        prob_lat = float(new_prob.get("latitude") or raw_rep.get("latitude", 0.0))
        prob_lon = float(new_prob.get("longitude") or raw_rep.get("longitude", 0.0))
        prob_addr = new_prob.get("address") or raw_rep.get("address", "")
        report_count = len(problem_analysis.get("relatedReportIds", [])) or 1

        problem_data = {
            "problemId": str(prob_id),
            "title": prob_title,
            "description": prob_desc,
            "category": prob_cat,
            "latitude": prob_lat,
            "longitude": prob_lon,
            "address": prob_addr,
            "reportCount": report_count,
        }

        # 2. Access Agent 1 structured observations via ADR-05 passthrough
        structured_report = (
            problem_analysis.get("structuredReport")
            or state.get("structured_report")
            or state.get("report_analysis")
        )

        # 3. Access available crews from state (populated by ASP.NET Core)
        available_crews = state.get("available_crews", [])

        # 4. Execute Agent 3 recommendation
        result: PriorityRecommendationOutput = await run_priority_recommendation(
            problem_data=problem_data,
            structured_report=structured_report,
            available_crews=available_crews,
        )

        logger.info(
            "[Workflow %s] Agent 3 completed successfully. Priority: %s (%d), Crew: %s (%s)",
            state.get("workflow_id"),
            result.priority.value,
            result.priority_score,
            result.recommended_crew_name or "N/A",
            result.recommended_crew_id,
        )

        result_dict = result.model_dump(by_alias=True)
        return {
            "priority_analysis": result_dict,
            "recommendations": [result_dict],
        }

    except Exception as ex:
        logger.exception("[Workflow %s] Agent 3 execution failed: %s", state.get("workflow_id"), ex)
        return {"error": f"Agent 3 failed: {ex}"}


# ────────────────────────────────────────────────────────────────
# 3. StateGraph Assembly & Compilation
# ────────────────────────────────────────────────────────────────

def build_mehewara_graph() -> StateGraph:
    """
    Assembles and compiles the full multi-agent workflow graph.
    Flow: START -> Agent 1 -> Agent 2 -> Agent 3 -> END (Agent 4 plug-in ready)
    """
    builder = StateGraph(MehewaraWorkflowState)

    # Register agent stage nodes
    builder.add_node("agent_1_report_analysis", agent_1_report_analysis_node)
    builder.add_node("agent_2_problem_consolidation", agent_2_problem_consolidation_node)
    builder.add_node("agent_3_prioritization", agent_3_prioritization_node)

    # Entry point & sequential transitions
    builder.set_entry_point("agent_1_report_analysis")
    builder.add_edge("agent_1_report_analysis", "agent_2_problem_consolidation")
    builder.add_edge("agent_2_problem_consolidation", "agent_3_prioritization")
    builder.add_edge("agent_3_prioritization", END)

    return builder.compile()


# Compiled singleton graph
mehewara_graph = build_mehewara_graph()


# ────────────────────────────────────────────────────────────────
# 4. Top-Level Workflow Executor
# ────────────────────────────────────────────────────────────────

async def run_mehewara_workflow(
    workflow_id: UUID | str,
    raw_report_dict: dict[str, Any],
    candidate_problems: list[dict[str, Any]] | None = None,
    related_reports: list[dict[str, Any]] | None = None,
    available_crews: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """
    Executes the multi-agent LangGraph workflow.
    Returns a unified response containing structured results for all executed agent stages.
    """
    initial_state: MehewaraWorkflowState = {
        "workflow_id": str(workflow_id),
        "raw_report": raw_report_dict,
        "candidate_problems": candidate_problems or [],
        "related_reports": related_reports or [],
        "available_crews": available_crews or [],
    }

    final_state = await mehewara_graph.ainvoke(initial_state)

    if final_state.get("error") and not final_state.get("problem_analysis"):
        error_msg = final_state["error"]
        logger.error("[Workflow %s] Workflow terminated with error: %s", workflow_id, error_msg)
        raise RuntimeError(error_msg)

    structured_report = final_state.get("structured_report")
    problem_analysis = final_state.get("problem_analysis")
    priority_analysis = final_state.get("priority_analysis")
    recommendations = final_state.get("recommendations")

    return {
        "workflow_id": str(workflow_id),
        "status": "completed",
        "report_analysis": structured_report,
        "problem_analysis": problem_analysis,
        "priority_analysis": priority_analysis,
        "recommendations": recommendations,
        # Backward compatibility alias for Member 1 ASP.NET Core client:
        "analysis": structured_report,
    }


def get_workflow_mermaid_diagram() -> str:
    """
    Returns the Mermaid markdown definition of the compiled LangGraph workflow.
    Useful for system documentation, architectural review, and viva evaluation.
    """
    return mehewara_graph.get_graph().draw_mermaid()

