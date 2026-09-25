"""
Mehewara AI Service — Unit & Integration Tests for Agent 2 (Problem Consolidation)

Tests cover:
- Schema validation & constraints (LINK_EXISTING, CREATE_NEW, UNCERTAIN)
- Absence of hallucinated 'confidence' score
- Tool execution & Haversine spatial calculations
- Candidate context management
- Cognitive consolidation mock tests (Golden Cases 1 to 5)
- Safe failure handling
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4
import pytest
from pydantic import ValidationError

from schemas.problem_consolidation import (
    ConsolidationDecision,
    NewProblemCandidate,
    ProblemConsolidationInputSchema,
    ProblemConsolidationOutputSchema,
    SourceReportPayload,
)
from schemas.report_analysis import MunicipalCategory, StructuredReport
from tools.problem_tools import (
    calculate_haversine_distance_meters,
    get_nearby_reports,
    get_problem_details,
    get_report_details,
    search_existing_problems,
    search_similar_reports,
    set_workflow_candidate_context,
)
from agents.problem_agent import consolidate_problem_with_agent


# ────────────────────────────────────────────────────────────────
# 1. Schemas & Constraints Tests
# ────────────────────────────────────────────────────────────────

def test_source_report_payload_creation():
    """Test valid construction of SourceReportPayload."""
    r_id = uuid4()
    payload = SourceReportPayload(
        reportId=r_id,
        description="Large crater pothole on Main Street",
        category="ROAD",
        latitude=6.9271,
        longitude=79.8612,
        address="123 Main St",
    )
    assert payload.report_id == r_id
    assert payload.category == "ROAD"
    assert payload.latitude == 6.9271


def test_output_schema_link_existing():
    """Test LINK_EXISTING decision output validation."""
    r_id = uuid4()
    p_id = uuid4()
    other_r_id = uuid4()
    data = {
        "reportId": str(r_id),
        "decision": "LINK_EXISTING",
        "problemId": str(p_id),
        "relatedReportIds": [str(r_id), str(other_r_id)],
        "summary": "Linked to existing pothole problem on Main St",
        "evidence": ["Same ROAD category", "Distance < 25m", "Matching pothole description"],
        "updatedProblemDescription": "Active pothole defect on Main Street expanding into left lane, posing vehicle hazard.",
    }
    output = ProblemConsolidationOutputSchema(**data)
    assert output.decision == ConsolidationDecision.LINK_EXISTING
    assert output.problem_id == p_id
    assert len(output.related_report_ids) == 2
    assert output.updated_problem_description is not None
    assert "confidence" not in output.model_dump()


def test_output_schema_create_new():
    """Test CREATE_NEW decision output validation."""
    r_id = uuid4()
    new_prob = NewProblemCandidate(
        title="Severe Drainage Blockage on Galle Road",
        category=MunicipalCategory.DRAINAGE,
        summary="Clogged culvert causing street overflow during rains",
        latitude=6.9310,
        longitude=79.8450,
        address="Galle Road, Junction 4",
    )
    output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.CREATE_NEW,
        problemId=None,
        newProblem=new_prob,
        relatedReportIds=[r_id],
        summary="Formed new Problem due to absence of matching drainage incidents nearby",
        evidence=["No active DRAINAGE problems within 500m radius"],
    )
    assert output.decision == ConsolidationDecision.CREATE_NEW
    assert output.problem_id is None
    assert output.new_problem is not None
    assert output.new_problem.category == MunicipalCategory.DRAINAGE


def test_output_schema_uncertain():
    """Test UNCERTAIN decision output validation."""
    r_id = uuid4()
    output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.UNCERTAIN,
        summary="Insufficient evidence to associate report with an existing or new problem",
        evidence=["Conflicting street names and ambiguous category"],
    )
    assert output.decision == ConsolidationDecision.UNCERTAIN
    assert output.problem_id is None
    assert output.new_problem is None


# ────────────────────────────────────────────────────────────────
# 2. Tool Unit & Spatial Calculation Tests
# ────────────────────────────────────────────────────────────────

def test_haversine_distance_calculation():
    """Test Haversine distance formula with known Colombo landmarks."""
    # Colombo Fort (6.9344, 79.8428) to Galle Face Green (6.9271, 79.8450)
    dist = calculate_haversine_distance_meters(6.9344, 79.8428, 6.9271, 79.8450)
    # Distance is roughly 850m - 900m
    assert 700 <= dist <= 1000

    # Same location should be zero
    assert calculate_haversine_distance_meters(6.900, 79.850, 6.900, 79.850) == 0.0


def test_candidate_context_and_tools():
    """Test tool searches over candidate problems and reports."""
    p1_id = str(uuid4())
    p2_id = str(uuid4())
    r1_id = str(uuid4())
    r2_id = str(uuid4())

    mock_problems = [
        {
            "problemId": p1_id,
            "title": "Pothole cluster on Main St",
            "category": "ROAD",
            "status": "OPEN",
            "latitude": 6.9271,
            "longitude": 79.8612,
            "address": "Main Street, Colombo 11",
            "reportCount": 2,
        },
        {
            "problemId": p2_id,
            "title": "Burst Water Pipe",
            "category": "DRAINAGE",
            "status": "OPEN",
            "latitude": 6.9350,
            "longitude": 79.8500,
            "address": "York Street",
            "reportCount": 1,
        },
    ]

    mock_reports = [
        {
            "reportId": r1_id,
            "problemId": p1_id,
            "description": "Deep hole on Main Street",
            "category": "ROAD",
            "latitude": 6.9272,
            "longitude": 79.8613,
            "address": "Main Street",
        },
        {
            "reportId": r2_id,
            "problemId": None,
            "description": "Another depression on road",
            "category": "ROAD",
            "latitude": 6.9270,
            "longitude": 79.8611,
            "address": "Main Street",
        },
    ]

    set_workflow_candidate_context(
        candidate_problems=mock_problems,
        related_reports=mock_reports,
    )

    # 1. Search existing problems by category and proximity
    results = search_existing_problems.invoke({
        "category": "ROAD",
        "latitude": 6.9271,
        "longitude": 79.8612,
        "radius_meters": 200.0,
    })
    assert len(results) == 1
    assert results[0]["problemId"] == p1_id

    # 2. Get problem details
    p_detail = get_problem_details.invoke({"problem_id": p1_id})
    assert p_detail["problemId"] == p1_id
    assert p_detail["category"] == "ROAD"

    p_missing = get_problem_details.invoke({"problem_id": "00000000-0000-0000-0000-000000000999"})
    assert p_missing.get("found") is False

    # 3. Search similar reports
    r_results = search_similar_reports.invoke({
        "observed_issue": "hole",
        "category": "ROAD",
        "latitude": 6.9271,
        "longitude": 79.8612,
        "radius_meters": 300.0,
    })
    assert len(r_results) >= 1
    assert r_results[0]["reportId"] == r1_id

    # 4. Get report details
    r_detail = get_report_details.invoke({"report_id": r1_id})
    assert r_detail["reportId"] == r1_id

    # 5. Get nearby reports
    nearby = get_nearby_reports.invoke({
        "latitude": 6.9271,
        "longitude": 79.8612,
        "radius_meters": 100.0,
    })
    assert len(nearby) == 2


# ────────────────────────────────────────────────────────────────
# 3. Cognitive Consolidation Mock Tests (Golden Cases 1 to 5)
# ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_case_1_link_existing():
    """Golden Case 1: Report matches an existing active problem."""
    r_id = uuid4()
    p_id = uuid4()
    structured = StructuredReport(
        reportId=r_id,
        observedIssue="Deep pothole in the left lane",
        affectedAsset="Asphalt road surface",
        reportedImpact=["Vehicle damage risk"],
        duration="3 days",
        hazards=["traffic hazard"],
        reportedCategory="ROAD",
        inferredCategory=MunicipalCategory.ROAD,
        categoryConfidence=0.95,
        missingInformation=[],
        imageAvailable=True,
    )
    source = SourceReportPayload(
        reportId=r_id,
        description="Deep pothole in the left lane on Main St",
        category="ROAD",
        latitude=6.9271,
        longitude=79.8612,
    )
    agent_input = ProblemConsolidationInputSchema(
        structuredReport=structured,
        sourceReport=source,
    )

    mock_output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.LINK_EXISTING,
        problemId=p_id,
        relatedReportIds=[r_id],
        summary="Linked to active Main St pothole cluster P001",
        evidence=["Same category ROAD", "Location within 20m of existing problem"],
    )

    with patch("agents.problem_agent.is_llm_configured", return_value=True), patch("agents.problem_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_output)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await consolidate_problem_with_agent(agent_input)

        assert result.decision == ConsolidationDecision.LINK_EXISTING
        assert result.problem_id == p_id
        assert r_id in result.related_report_ids


@pytest.mark.asyncio
async def test_case_2_create_new():
    """Golden Case 2: Report has no matching problem, creates a new problem."""
    r_id = uuid4()
    structured = StructuredReport(
        reportId=r_id,
        observedIssue="Overflowing public garbage bin",
        affectedAsset="Municipal waste container",
        reportedImpact=["Odor and litter"],
        duration="2 days",
        hazards=["Health risk"],
        reportedCategory="WASTE",
        inferredCategory=MunicipalCategory.WASTE,
        categoryConfidence=0.92,
        missingInformation=[],
        imageAvailable=False,
    )
    source = SourceReportPayload(
        reportId=r_id,
        description="Overflowing public garbage bin on 2nd cross street",
        category="WASTE",
        latitude=6.9500,
        longitude=79.8700,
    )
    agent_input = ProblemConsolidationInputSchema(
        structuredReport=structured,
        sourceReport=source,
    )

    new_candidate = NewProblemCandidate(
        title="Overflowing Waste Container on 2nd Cross Street",
        category=MunicipalCategory.WASTE,
        summary="Waste container overflowing onto pedestrian sidewalk",
        latitude=6.9500,
        longitude=79.8700,
    )
    mock_output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.CREATE_NEW,
        problemId=None,
        newProblem=new_candidate,
        relatedReportIds=[r_id],
        summary="Formed new municipal problem for waste container overflow",
        evidence=["No existing waste problems in this sector"],
    )

    with patch("agents.problem_agent.is_llm_configured", return_value=True), patch("agents.problem_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_output)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await consolidate_problem_with_agent(agent_input)

        assert result.decision == ConsolidationDecision.CREATE_NEW
        assert result.problem_id is None
        assert result.new_problem is not None
        assert result.new_problem.category == MunicipalCategory.WASTE


@pytest.mark.asyncio
async def test_case_5_uncertain():
    """Golden Case 5: Ambiguous report produces UNCERTAIN decision without hallucination."""
    r_id = uuid4()
    structured = StructuredReport(
        reportId=r_id,
        observedIssue="Broken streetlight pole",
        affectedAsset="Lamppost",
        reportedImpact=[],
        duration=None,
        hazards=["Dark intersection"],
        reportedCategory="ELECTRICAL",
        inferredCategory=MunicipalCategory.ELECTRICAL,
        categoryConfidence=0.6,
        missingInformation=["Street address unclear"],
        imageAvailable=False,
    )
    source = SourceReportPayload(
        reportId=r_id,
        description="A light is broken somewhere around here",
        category="ELECTRICAL",
        latitude=0.0,
        longitude=0.0,
    )
    agent_input = ProblemConsolidationInputSchema(
        structuredReport=structured,
        sourceReport=source,
    )

    mock_output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.UNCERTAIN,
        problemId=None,
        newProblem=None,
        relatedReportIds=[r_id],
        summary="Insufficient evidence to associate report with an existing or new problem",
        evidence=["Coordinates missing", "Vague description"],
    )

    with patch("agents.problem_agent.is_llm_configured", return_value=True), patch("agents.problem_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_output)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await consolidate_problem_with_agent(agent_input)

        assert result.decision == ConsolidationDecision.UNCERTAIN
        assert result.problem_id is None
        assert result.new_problem is None
