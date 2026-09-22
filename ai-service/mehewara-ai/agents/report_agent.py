"""
Mehewara AI Service — Agent 1: Report Analysis & Structuring

Implements Agent 1 in compliance with the Member 1 specification and marking rubric:
- Core Question: "What information does the resident's report actually contain?"
- Anti-hallucination: Never invent invisible root causes (e.g. 'pipe collapsed underground').
- Scope: Only analyze & structure observable evidence. Never assign priority or dispatch crews.
- Gap detection: Record omissions in missingInformation.
- Tool Integration: Allow-listed LangChain @tool decorators for least-privilege context retrieval.
"""

from __future__ import annotations

import json
import logging
from typing import Any, TypedDict
from uuid import UUID

from app.config import settings
from app.llm import get_llm, is_llm_configured
from schemas.report_analysis import MunicipalCategory, ReportInputSchema, StructuredReport
from tools.report_tools import (
    AGENT_1_TOOLS,
    analyze_category_hints,
    get_asset_context,
    get_location_context,
    get_municipal_asset_catalog,
)

logger = logging.getLogger(__name__)


# ────────────────────────────────────────────────────────────────
# Agent 1 State Definition (for LangGraph pipeline)
# ────────────────────────────────────────────────────────────────

class Agent1State(TypedDict, total=False):
    """Workflow state flowing through Agent 1 nodes."""
    raw_report: dict[str, Any]
    location_context: dict[str, Any]
    asset_catalog: list[str]
    structured_report: dict[str, Any] | None
    error: str | None


# ────────────────────────────────────────────────────────────────
# System Prompt with Strict Anti-Hallucination Guardrails
# ────────────────────────────────────────────────────────────────

AGENT_1_SYSTEM_PROMPT = """You are Agent 1 (Report Analysis & Structuring) for the Mehewara Municipal Works Management System.

Your SOLE responsibility is to analyze raw citizen reports and extract strictly observable, evidence-grounded facts.

### STRICT GUARDRAILS (Marking Rubric Compliance):
1. **NON-HALLUCINATION:**
   - Extract ONLY what is explicitly stated in the text.
   - NEVER invent or speculate on invisible root causes (e.g., if the user says "water is collecting on the asphalt", DO NOT say "drainage pipe burst underground" or "culvert collapsed". Simply state "water accumulation on road surface").
2. **SCOPE BOUNDARY:**
   - DO NOT determine priority (LOW/MEDIUM/HIGH/CRITICAL) — that is owned by Agent 3.
   - DO NOT recommend crews or dispatch teams — that is owned by Agent 3 & 4.
   - DO NOT merge reports or detect duplicates — that is owned by Agent 2.
3. **GAP PRESERVATION:**
   - If a fact is unstated (e.g. duration, exact dimensions, specific hazard), preserve it as null and record the omission explicitly in `missingInformation`.
4. **CATEGORY CLASSIFICATION:**
   - Keep `reportedCategory` (what the citizen picked) separate from `inferredCategory`.
   - `inferredCategory` MUST be exactly one of: ROAD, DRAINAGE, WASTE, ELECTRICAL, ENVIRONMENT.

### Authoritative Output Fields:
- `observedIssue`: Primary observable defect or physical condition described by the citizen.
- `affectedAsset`: Specific municipal physical asset affected (e.g., road surface, streetlight, stormwater drain, sidewalk).
- `reportedImpact`: Explicit impact stated by citizen (e.g. "traffic blocked", "pedestrians slipping"), or null if unmentioned.
- `duration`: How long the issue has persisted if stated (e.g. "since yesterday", "3 days"), or null.
- `hazards`: List of explicit safety hazards mentioned in the report.
- `reportedCategory`: Citizen's input category.
- `inferredCategory`: Exactly one of: ROAD, DRAINAGE, WASTE, ELECTRICAL, ENVIRONMENT.
- `categoryConfidence`: Float 0.0 to 1.0.
- `missingInformation`: Array of critical omitted details (e.g. "no photos provided", "exact depth/size not specified", "duration unstated").
- `imageAvailable`: Boolean (true if photos attached).
"""


def _build_deterministic_structured_report(
    report_input: ReportInputSchema,
) -> StructuredReport:
    """
    Deterministic rule-based fallback extractor for offline testing or when
    the LLM API is unavailable.
    """
    desc = report_input.description
    desc_lower = desc.lower()

    # Determine inferred category via keyword scan
    inferred_cat_str, confidence = analyze_category_hints(desc)
    try:
        inferred_cat = MunicipalCategory(inferred_cat_str)
    except ValueError:
        inferred_cat = MunicipalCategory.ENVIRONMENT

    # Find affected asset from @tool catalog
    catalog: list[str] = get_municipal_asset_catalog.invoke({"category": inferred_cat.value})
    affected_asset = "municipal infrastructure"
    for asset in catalog:
        if asset.lower() in desc_lower:
            affected_asset = asset
            break
    if affected_asset == "municipal infrastructure" and catalog:
        affected_asset = catalog[0]

    # Extract duration hints
    duration: str | None = None
    duration_indicators = ["day", "days", "week", "weeks", "month", "months", "since", "yesterday", "hours", "past"]
    for word in desc.split():
        for ind in duration_indicators:
            if ind in word.lower():
                words = desc.split()
                idx = words.index(word)
                start = max(0, idx - 1)
                end = min(len(words), idx + 2)
                duration = " ".join(words[start:end])
                break
        if duration:
            break

    # Extract hazards
    hazards: list[str] = []
    if any(h in desc_lower for h in ["danger", "accident", "damage", "collision", "fall", "injury"]):
        hazards.append("safety / accident hazard noted in description")
    if any(h in desc_lower for h in ["spark", "shock", "electrocution", "live wire"]):
        hazards.append("electrical hazard")
    if any(h in desc_lower for h in ["flood", "drown", "waterlogging"]):
        hazards.append("waterlogging / flood hazard")

    # Missing information checklist
    missing: list[str] = []
    if len(report_input.photos) == 0:
        missing.append("no photographic evidence attached")
    if duration is None:
        missing.append("duration / timeline of issue not stated")
    if not any(dim in desc_lower for dim in ["cm", "m", "meter", "feet", "inch", "large", "small", "deep", "wide"]):
        missing.append("physical dimensions / severity magnitude not quantified")

    return StructuredReport(
        report_id=report_input.id,
        observed_issue=desc.strip(),
        affected_asset=affected_asset,
        reported_impact="Impact described in report" if any(i in desc_lower for i in ["block", "cannot", "damage", "prevent", "hard"]) else None,
        duration=duration,
        hazards=hazards,
        reported_category=report_input.category,
        inferred_category=inferred_cat,
        category_confidence=confidence,
        missing_information=missing,
        image_available=len(report_input.photos) > 0,
    )


async def analyze_report_with_llm(
    report_input: ReportInputSchema,
) -> StructuredReport:
    """
    Execute Agent 1 report analysis using Google Gemini with structured Pydantic output
    and allow-listed @tool bindings.
    """
    # If no Gemini API key is configured or set to default placeholder, use deterministic engine
    if not is_llm_configured():
        logger.info("Using deterministic extractor (GEMINI_API_KEY not configured)")
        return _build_deterministic_structured_report(report_input)

    try:
        from langchain_core.messages import HumanMessage, SystemMessage

        # Get shared configured LLM instance from centralized factory
        llm = get_llm(temperature=0.1)

        # Bind allow-listed tools and structured output schema
        llm_with_tools = llm.bind_tools(AGENT_1_TOOLS)
        structured_llm = llm_with_tools.with_structured_output(StructuredReport)

        location_info: dict = get_location_context.invoke({
            "latitude": report_input.latitude,
            "longitude": report_input.longitude,
            "address": report_input.address,
        })
        asset_catalog: list[str] = get_municipal_asset_catalog.invoke({})

        user_content = f"""Please analyze this citizen report:
Report ID: {report_input.id}
Reported Category: {report_input.category}
Coordinates: ({report_input.latitude}, {report_input.longitude})
Address: {location_info['address']}
Photos Attached: {len(report_input.photos)} photo(s)

Resident Description:
"{report_input.description}"

Standard Municipal Assets Available:
{json.dumps(asset_catalog[:15], indent=2)}

Remember: Extract ONLY observable facts. Do NOT speculate on invisible root causes. Populate missingInformation for any gaps.
"""

        result = await structured_llm.ainvoke([
            SystemMessage(content=AGENT_1_SYSTEM_PROMPT),
            HumanMessage(content=user_content),
        ])

        if isinstance(result, StructuredReport):
            result.report_id = report_input.id
            result.image_available = len(report_input.photos) > 0
            return result

        if isinstance(result, dict):
            result["reportId"] = report_input.id
            result["imageAvailable"] = len(report_input.photos) > 0
            return StructuredReport(**result)

        logger.warning("LLM returned non-StructuredReport object (%s), falling back", type(result))
        return _build_deterministic_structured_report(report_input)

    except Exception as ex:
        logger.exception("LLM extraction failed (%s). Using deterministic fallback.", ex)
        return _build_deterministic_structured_report(report_input)
