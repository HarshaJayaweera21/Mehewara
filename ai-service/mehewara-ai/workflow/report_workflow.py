"""
Mehewara AI Service — LangGraph Report Workflow Pipeline

Orchestrates the Agent 1 report processing pipeline using LangGraph:
1. Ingestion & Context Node: Invokes allow-listed LangChain @tool objects
2. Extraction Node: Executes Agent 1 LLM with anti-hallucination guardrails and tool binding
3. Schema & Validation Node: Enforces Pydantic output constraints
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from langgraph.graph import END, StateGraph

from agents.report_agent import Agent1State, analyze_report_with_llm
from schemas.report_analysis import MunicipalCategory, ReportInputSchema, StructuredReport
from tools.report_tools import get_location_context, get_municipal_asset_catalog

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────
# LangGraph Workflow Nodes
# ────────────────────────────────────────────────────────────────

async def ingest_and_context_node(state: Agent1State) -> dict[str, Any]:
    """Node 1: Gather spatial context and asset catalogs for Agent 1 via @tool invocations."""
    raw = state.get("raw_report", {})
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

    return {
        "location_context": location_ctx,
        "asset_catalog": assets,
    }


async def extract_report_node(state: Agent1State) -> dict[str, Any]:
    """Node 2: Run Agent 1 extraction with strict anti-hallucination prompt and tool context."""
    raw = state.get("raw_report", {})
    try:
        report_input = ReportInputSchema(**raw)
        structured = await analyze_report_with_llm(report_input)
        return {
            "structured_report": structured.model_dump(by_alias=True),
        }
    except Exception as ex:
        logger.exception("Error in extract_report_node: %s", ex)
        return {
            "error": str(ex),
        }


async def validate_guardrails_node(state: Agent1State) -> dict[str, Any]:
    """Node 3: Final schema validation and sanity check on extracted facts."""
    structured_data = state.get("structured_report")
    if not structured_data:
        return {"error": state.get("error") or "No structured report produced"}

    # Re-validate through Pydantic schema
    try:
        validated = StructuredReport(**structured_data)
        assert validated.inferred_category in MunicipalCategory
        assert 0.0 <= validated.category_confidence <= 1.0
        return {
            "structured_report": validated.model_dump(by_alias=True),
        }
    except Exception as ex:
        logger.error("Validation error in Agent 1 guardrails: %s", ex)
        return {"error": f"Schema validation failed: {ex}"}


# ────────────────────────────────────────────────────────────────
# LangGraph StateGraph Compilation
# ────────────────────────────────────────────────────────────────

def build_report_analysis_graph() -> StateGraph:
    """Build the compiled LangGraph execution graph for Agent 1."""
    builder = StateGraph(Agent1State)

    builder.add_node("ingest_context", ingest_and_context_node)
    builder.add_node("extract_report", extract_report_node)
    builder.add_node("validate_guardrails", validate_guardrails_node)

    builder.set_entry_point("ingest_context")
    builder.add_edge("ingest_context", "extract_report")
    builder.add_edge("extract_report", "validate_guardrails")
    builder.add_edge("validate_guardrails", END)

    return builder.compile()


# Compiled singleton graph
report_agent_graph = build_report_analysis_graph()


# ────────────────────────────────────────────────────────────────
# High-Level Execution Helper
# ────────────────────────────────────────────────────────────────

async def run_report_analysis_workflow(raw_report_dict: dict[str, Any]) -> StructuredReport:
    """
    Execute the compiled LangGraph workflow for a single incoming report.
    Returns the validated StructuredReport output.
    """
    initial_state: Agent1State = {
        "raw_report": raw_report_dict,
    }

    final_state = await report_agent_graph.ainvoke(initial_state)

    if final_state.get("structured_report"):
        return StructuredReport(**final_state["structured_report"])

    logger.warning("Workflow returned with errors: %s. Using fallback.", final_state.get("error"))
    report_input = ReportInputSchema(**raw_report_dict)
    return await analyze_report_with_llm(report_input)
