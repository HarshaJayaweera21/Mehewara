"""
Mehewara AI Service — Unit & Integration Tests for Agent 3 (Priority & Crew Recommendation Agent)

Tests all criteria outlined in Rubric §9.1 and member_3_development_plan.md:
- Pydantic schema boundaries (priority score 0-100, enums, required fields)
- Allow-listed crew tools (get_crew_capabilities, check_crew_availability, get_recent_jobs)
- Deterministic prioritization heuristics (CRITICAL, HIGH, MEDIUM, LOW)
- Category to CrewType matching
- Busy crew constraint detection
- Safe failure & graceful bypass when Agent 2 is UNCERTAIN
- End-to-end execution with mocked LLM
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4
import pytest
from pydantic import ValidationError

from agents.priority_crew_agent import (
    _generate_deterministic_fallback,
    run_priority_recommendation,
)
from schemas.priority_recommendation import (
    CrewType,
    PriorityLevel,
    PriorityRecommendationInput,
    PriorityRecommendationOutput,
)
from tools.crew_tools import (
    check_crew_availability,
    get_crew_capabilities,
    get_recent_jobs,
    set_workflow_crew_context,
)
from workflow.mehewara_workflow import agent_3_prioritization_node


# ────────────────────────────────────────────────────────────────
# 1. Pydantic Schema Validation Tests
# ────────────────────────────────────────────────────────────────

def test_priority_recommendation_output_valid():
    """Verify that a well-formed payload validates successfully."""
    payload = {
        "problemId": str(uuid4()),
        "priority": "HIGH",
        "priorityScore": 75,
        "priorityReasons": ["Substantial stormwater flooding across road", "Multiple resident reports"],
        "requiredCrewType": "DRAINAGE",
        "recommendedCrewId": str(uuid4()),
        "recommendedCrewName": "Drainage Unit Alpha",
        "recommendationReason": "Drainage Unit Alpha is specialized and currently available.",
    }
    model = PriorityRecommendationOutput(**payload)
    assert model.priority == PriorityLevel.HIGH
    assert model.priority_score == 75
    assert model.required_crew_type == CrewType.DRAINAGE
    assert model.recommended_crew_name == "Drainage Unit Alpha"


def test_priority_score_boundaries():
    """Verify that scores < 0 or > 100 are rejected by Pydantic."""
    base = {
        "problemId": str(uuid4()),
        "priority": "MEDIUM",
        "priorityReasons": ["Reason"],
        "requiredCrewType": "ROAD",
        "recommendedCrewId": str(uuid4()),
        "recommendationReason": "Valid reason for dispatch.",
    }

    # Negative score should fail
    with pytest.raises(ValidationError):
        PriorityRecommendationOutput(**base, priorityScore=-1)

    # Score > 100 should fail
    with pytest.raises(ValidationError):
        PriorityRecommendationOutput(**base, priorityScore=105)

    # Valid score 0 and 100 should pass
    m0 = PriorityRecommendationOutput(**base, priorityScore=0)
    assert m0.priority_score == 0

    m100 = PriorityRecommendationOutput(**base, priorityScore=100)
    assert m100.priority_score == 100


def test_invalid_enums():
    """Verify that invalid priority levels or crew types are rejected."""
    base = {
        "problemId": str(uuid4()),
        "priorityScore": 50,
        "priorityReasons": ["Reason"],
        "recommendedCrewId": str(uuid4()),
        "recommendationReason": "Valid reason for dispatch.",
    }

    with pytest.raises(ValidationError):
        PriorityRecommendationOutput(**base, priority="URGENT", requiredCrewType="ROAD")

    with pytest.raises(ValidationError):
        PriorityRecommendationOutput(**base, priority="HIGH", requiredCrewType="PLUMBING")


# ────────────────────────────────────────────────────────────────
# 2. Allow-Listed Crew Tools Tests
# ────────────────────────────────────────────────────────────────

@pytest.fixture
def mock_crews_context():
    """Standard seeded crew context for testing."""
    return [
        {
            "crewId": "c0000000-0000-0000-0000-000000000001",
            "name": "Drainage Rapid Response Unit Alpha",
            "crewType": "DRAINAGE",
            "status": "AVAILABLE",
            "activeWorkOrderId": None,
        },
        {
            "crewId": "c0000000-0000-0000-0000-000000000002",
            "name": "Road Maintenance Crew Bravo",
            "crewType": "ROAD",
            "status": "AVAILABLE",
            "activeWorkOrderId": None,
        },
        {
            "crewId": "c0000000-0000-0000-0000-000000000004",
            "name": "Electrical Services Delta",
            "crewType": "ELECTRICAL",
            "status": "BUSY",
            "activeWorkOrderId": "ff000000-0000-0000-0000-000000000001",
        },
    ]


def test_crew_tools(mock_crews_context):
    """Verify allow-listed tools query context correctly."""
    set_workflow_crew_context(mock_crews_context)

    # 1. get_crew_capabilities
    caps = get_crew_capabilities.invoke({})
    assert len(caps) == 3
    assert any(c["name"] == "Drainage Rapid Response Unit Alpha" for c in caps)

    # 2. check_crew_availability (all available)
    avail = check_crew_availability.invoke({})
    assert len(avail) == 2
    assert all(c["status"] == "AVAILABLE" for c in avail)

    # 3. check_crew_availability (filtered by type)
    drainage_avail = check_crew_availability.invoke({"crew_type": "DRAINAGE"})
    assert len(drainage_avail) == 1
    assert drainage_avail[0]["crewType"] == "DRAINAGE"

    electrical_avail = check_crew_availability.invoke({"crew_type": "ELECTRICAL"})
    assert len(electrical_avail) == 0  # Delta is BUSY

    # 4. get_recent_jobs
    busy_jobs = get_recent_jobs.invoke({"crew_id": "c0000000-0000-0000-0000-000000000004"})
    assert len(busy_jobs) == 1
    assert busy_jobs[0]["workOrderId"] == "ff000000-0000-0000-0000-000000000001"

    free_jobs = get_recent_jobs.invoke({"crew_id": "c0000000-0000-0000-0000-000000000001"})
    assert len(free_jobs) == 0


# ────────────────────────────────────────────────────────────────
# 3. Prioritization Logic & Heuristics Tests
# ────────────────────────────────────────────────────────────────

def test_critical_priority_evaluation(mock_crews_context):
    """Severe hazard (live wire, hospital blocked) evaluates to CRITICAL with score >= 85."""
    problem = {
        "problemId": str(uuid4()),
        "title": "Live electrical wire sparking near hospital entrance",
        "description": "Fallen power cable sparking in floodwater blocking emergency ambulance access.",
        "category": "ELECTRICAL",
        "reportCount": 2,
    }
    result = _generate_deterministic_fallback(problem, None, mock_crews_context)
    assert result.priority == PriorityLevel.CRITICAL
    assert result.priority_score >= 85
    assert result.required_crew_type == CrewType.ELECTRICAL


def test_high_priority_evaluation(mock_crews_context):
    """Major road flooding or multiple complaints evaluates to HIGH with score 60-84."""
    problem = {
        "problemId": str(uuid4()),
        "title": "Blocked roadside drain causing severe road flooding",
        "description": "Overflowing stormwater drain with multiple complaints on Galle Road.",
        "category": "DRAINAGE",
        "reportCount": 4,
    }
    result = _generate_deterministic_fallback(problem, None, mock_crews_context)
    assert result.priority == PriorityLevel.HIGH
    assert 60 <= result.priority_score <= 84
    assert result.required_crew_type == CrewType.DRAINAGE
    assert result.recommended_crew_id == "c0000000-0000-0000-0000-000000000001"
    assert "Alpha" in (result.recommended_crew_name or "")


def test_medium_priority_evaluation(mock_crews_context):
    """Localized pothole or illegal dump evaluates to MEDIUM with score 30-59."""
    problem = {
        "problemId": str(uuid4()),
        "title": "Pothole on residential by-lane",
        "description": "Deep asphalt pothole causing bumpy travel for three-wheelers.",
        "category": "ROAD",
        "reportCount": 1,
    }
    result = _generate_deterministic_fallback(problem, None, mock_crews_context)
    assert result.priority == PriorityLevel.MEDIUM
    assert 30 <= result.priority_score <= 59
    assert result.required_crew_type == CrewType.ROAD
    assert result.recommended_crew_id == "c0000000-0000-0000-0000-000000000002"


def test_low_priority_evaluation(mock_crews_context):
    """Minor cosmetic issue evaluates to LOW with score < 30."""
    problem = {
        "problemId": str(uuid4()),
        "title": "Faded zebra crossing markings",
        "description": "Paint markings slightly faded along school crosswalk.",
        "category": "ROAD",
        "reportCount": 1,
    }
    result = _generate_deterministic_fallback(problem, None, mock_crews_context)
    assert result.priority == PriorityLevel.LOW
    assert result.priority_score < 30


def test_busy_crew_constraint_handling(mock_crews_context):
    """When matching crew is BUSY, recommendation reason explicitly flags the busy status."""
    problem = {
        "problemId": str(uuid4()),
        "title": "Streetlight failure along dark junction",
        "description": "Inoperable streetlights at dark intersection.",
        "category": "ELECTRICAL",
        "reportCount": 1,
    }
    result = _generate_deterministic_fallback(problem, None, mock_crews_context)
    assert result.required_crew_type == CrewType.ELECTRICAL
    assert "BUSY" in result.recommendation_reason


# ────────────────────────────────────────────────────────────────
# 4. Safe Failure & Node Bypass Tests (ADR-06)
# ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_agent_3_node_uncertain_bypass():
    """Verify Agent 3 safely bypasses prioritization when Agent 2 outputs UNCERTAIN."""
    state = {
        "workflow_id": str(uuid4()),
        "raw_report": {"id": str(uuid4()), "category": "DRAINAGE"},
        "problem_analysis": {
            "decision": "UNCERTAIN",
            "summary": "Report evidence is conflicting and ambiguous.",
            "problemId": None,
        },
        "available_crews": [],
    }

    result = await agent_3_prioritization_node(state)
    assert result.get("priority_analysis") is None
    assert result.get("recommendations") == []


@pytest.mark.asyncio
async def test_agent_3_node_missing_agent2():
    """Verify Agent 3 safely handles missing Agent 2 output."""
    state = {
        "workflow_id": str(uuid4()),
        "raw_report": {"id": str(uuid4())},
        "problem_analysis": None,
    }

    result = await agent_3_prioritization_node(state)
    assert result.get("priority_analysis") is None
    assert result.get("recommendations") == []


# ────────────────────────────────────────────────────────────────
# 5. Mocked LLM Execution Test
# ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_run_priority_recommendation_mocked_llm(mock_crews_context):
    """Verify run_priority_recommendation execution using a mocked LLM response."""
    prob_id = str(uuid4())
    mock_output = PriorityRecommendationOutput(
        problemId=prob_id,
        priority=PriorityLevel.HIGH,
        priorityScore=80,
        priorityReasons=["Major arterial road drainage blocked", "Potential flood risk"],
        requiredCrewType=CrewType.DRAINAGE,
        recommendedCrewId="c0000000-0000-0000-0000-000000000001",
        recommendedCrewName="Drainage Rapid Response Unit Alpha",
        recommendationReason="Unit Alpha is specialized for drainage and is currently available.",
    )

    with patch("agents.priority_crew_agent.is_llm_configured", return_value=True), \
         patch("agents.priority_crew_agent.get_llm") as mock_get_llm:
        mock_structured_llm = AsyncMock()
        mock_structured_llm.ainvoke.return_value = mock_output
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        res = await run_priority_recommendation(
            problem_data={"problemId": prob_id, "title": "Blocked drain", "category": "DRAINAGE"},
            structured_report={"observedIssue": "Drainage blocked"},
            available_crews=mock_crews_context,
        )

        assert res.priority == PriorityLevel.HIGH
        assert res.priority_score == 80
        assert res.required_crew_type == CrewType.DRAINAGE
        assert res.recommended_crew_id == "c0000000-0000-0000-0000-000000000001"
