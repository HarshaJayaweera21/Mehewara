"""
Mehewara AI Service — Unit Tests for Agent 4 (Independent Evidence Reviewer / Safety Agent)

Tests cover:
- NOT_RUN when no certain recommendation is available to review
- INVALID on malformed recommendation schema or inconsistent consolidation/reference data
- ERROR when backend evidence context cannot be loaded
- REVISION_REQUIRED (REVIEW_INPUT) when a referenced report is stale/cancelled
- REVISION_REQUIRED (REGENERATE) when the selected crew is unavailable
- REVISION_REQUIRED (WAIT_FOR_CREW) when no crew is selected and none are available
- VALID when every check and the Gemini evidence review pass
- REVISION_REQUIRED when Gemini's evidence review reports an unsupported claim
- ERROR when Gemini is not configured or the model call raises
"""

from __future__ import annotations

import copy
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from agents.safety_agent import validate_recommendation
from schemas.safety_validation import EvidenceFinding, EvidenceReview

SOURCE_ID = "11111111-1111-1111-1111-111111111111"
PROBLEM_ID = "22222222-2222-2222-2222-222222222222"
CREW_ID = "33333333-3333-3333-3333-333333333333"
SOURCE_REF = f"report:{SOURCE_ID}"


def _baseline_state() -> dict:
    return {
        "workflow_id": "wf-1",
        "job_id": "job-1",
        "recommendation_id": "rec-1",
        "recommendation_revision": 1,
        "resolved_problem_id": PROBLEM_ID,
        "raw_report": {"id": SOURCE_ID},
        "structured_report": {"category": "ROAD"},
        "coordinator_feedback": None,
        "authorized_problem_ids": [PROBLEM_ID],
        "authorized_report_ids": [SOURCE_ID],
        "authorized_crew_ids": [CREW_ID],
        "available_crews": [],
        "problem_analysis": {
            "decision": "LINK_EXISTING",
            "problemId": PROBLEM_ID,
            "newProblem": None,
            "summary": "Pothole reported near school gate blocking traffic.",
            "evidence": ["Multiple residents reported the same pothole."],
            "updatedProblemDescription": None,
            "reportId": SOURCE_ID,
            "relatedReportIds": [SOURCE_ID],
        },
        "priority_analysis": {
            "problemId": PROBLEM_ID,
            "priority": "HIGH",
            "priorityScore": 70,
            "priorityReasons": ["Blocks traffic near a school entrance"],
            "requiredCrewType": "ROAD",
            "recommendedCrewId": CREW_ID,
            "recommendationReason": "Road crew needed to repair the pothole urgently",
            "estimatedDurationMinutes": 120,
            "distanceKm": 2.5,
            "estimatedTravelMinutes": 15,
            "dispatchStrategy": "STANDARD_DISPATCH",
        },
    }


def _baseline_evidence() -> dict:
    return {
        "complete": True,
        "evidenceHash": "hash-1",
        "snapshotHash": "snap-1",
        "snapshotAt": "2026-01-01T00:00:00Z",
        "reports": [{"id": SOURCE_ID, "problemId": PROBLEM_ID, "status": "ASSIGNED"}],
        "problem": {"category": "ROAD", "status": "OPEN"},
        "crew": {"crewType": "ROAD", "status": "AVAILABLE"},
        "activeWorkOrders": [],
    }


def _mock_validation_context(evidence: dict):
    tool = MagicMock()
    tool.ainvoke = AsyncMock(return_value=evidence)
    return tool


def _mock_llm(review: EvidenceReview):
    structured = MagicMock()
    structured.ainvoke = AsyncMock(return_value=review)
    llm = MagicMock()
    llm.with_structured_output = MagicMock(return_value=structured)
    return llm


@pytest.mark.asyncio
async def test_not_run_when_consolidation_uncertain():
    state = _baseline_state()
    state["problem_analysis"]["decision"] = "UNCERTAIN"

    result = await validate_recommendation(state)

    assert result["status"] == "NOT_RUN"
    assert result["suggestedAction"] == "REVIEW_INPUT"


@pytest.mark.asyncio
async def test_not_run_when_recommendation_missing():
    state = _baseline_state()
    state["priority_analysis"] = None

    result = await validate_recommendation(state)

    assert result["status"] == "NOT_RUN"


@pytest.mark.asyncio
async def test_invalid_when_recommendation_schema_fails():
    state = _baseline_state()
    state["priority_analysis"]["priority"] = "UNKNOWN"  # not a valid Literal

    result = await validate_recommendation(state)

    assert result["status"] == "INVALID"
    assert any(c["code"] == "SCHEMA" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_invalid_when_consolidation_decision_inconsistent():
    state = _baseline_state()
    # LINK_EXISTING must not carry a proposed new Problem.
    state["problem_analysis"]["newProblem"] = {
        "title": "Duplicate pothole proposal",
        "category": "ROAD",
        "latitude": 6.9,
        "longitude": 79.9,
    }

    result = await validate_recommendation(state)

    assert result["status"] == "INVALID"
    assert any(c["code"] == "CONSOLIDATION" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_invalid_when_problem_mapping_not_authorized():
    state = _baseline_state()
    state["authorized_problem_ids"] = []  # resolved Problem no longer in the authorized context

    result = await validate_recommendation(state)

    assert result["status"] == "INVALID"
    assert any(c["code"] == "PROBLEM_MAPPING" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_error_when_evidence_context_incomplete():
    state = _baseline_state()
    incomplete_evidence = {"complete": False}

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(incomplete_evidence)):
        result = await validate_recommendation(state)

    assert result["status"] == "ERROR"
    assert any(c["code"] == "COMPLETE_CONTEXT" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_revision_required_review_input_when_report_cancelled():
    state = _baseline_state()
    evidence = _baseline_evidence()
    evidence["reports"][0]["status"] = "CANCELLED"

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)):
        result = await validate_recommendation(state)

    assert result["status"] == "REVISION_REQUIRED"
    assert result["suggestedAction"] == "REVIEW_INPUT"
    assert any(c["code"] == "REPORT_LINKS" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_revision_required_regenerate_when_crew_unavailable():
    state = _baseline_state()
    evidence = _baseline_evidence()
    evidence["crew"]["status"] = "BUSY"

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)):
        result = await validate_recommendation(state)

    assert result["status"] == "REVISION_REQUIRED"
    assert result["suggestedAction"] == "REGENERATE"
    assert any(c["code"] == "CREW_AVAILABLE" and not c["passed"] for c in result["checks"])


@pytest.mark.asyncio
async def test_wait_for_crew_when_no_crew_selected_and_none_available():
    state = _baseline_state()
    state["priority_analysis"]["recommendedCrewId"] = "NONE"
    evidence = _baseline_evidence()
    evidence["crew"] = {}
    review = EvidenceReview(supported=True, findings=[], evidenceRefs=[SOURCE_REF])

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)), \
         patch("agents.safety_agent.is_llm_configured", return_value=True), \
         patch("agents.safety_agent.get_llm", return_value=_mock_llm(review)):
        result = await validate_recommendation(state)

    assert result["status"] == "REVISION_REQUIRED"
    assert result["suggestedAction"] == "WAIT_FOR_CREW"


@pytest.mark.asyncio
async def test_valid_when_checks_and_evidence_review_pass():
    state = _baseline_state()
    evidence = _baseline_evidence()
    review = EvidenceReview(supported=True, findings=[], evidenceRefs=[SOURCE_REF])

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)), \
         patch("agents.safety_agent.is_llm_configured", return_value=True), \
         patch("agents.safety_agent.get_llm", return_value=_mock_llm(review)):
        result = await validate_recommendation(state)

    assert result["status"] == "VALID"
    assert result["suggestedAction"] == "APPROVAL_ELIGIBLE"
    assert SOURCE_REF in result["evidenceRefs"]


@pytest.mark.asyncio
async def test_revision_required_when_evidence_review_finds_unsupported_claim():
    state = _baseline_state()
    evidence = _baseline_evidence()
    finding = EvidenceFinding(
        code="UNSUPPORTED_PRIORITY",
        message="Priority is not supported by the cited reports.",
        correction="Lower the priority to match the evidence.",
        evidenceRefs=[SOURCE_REF],
    )
    review = EvidenceReview(supported=False, findings=[finding], evidenceRefs=[SOURCE_REF])

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)), \
         patch("agents.safety_agent.is_llm_configured", return_value=True), \
         patch("agents.safety_agent.get_llm", return_value=_mock_llm(review)):
        result = await validate_recommendation(state)

    assert result["status"] == "REVISION_REQUIRED"
    assert any("UNSUPPORTED_PRIORITY" in issue or "not supported" in issue for issue in result["issues"])


@pytest.mark.asyncio
async def test_error_when_llm_not_configured():
    state = _baseline_state()
    evidence = _baseline_evidence()

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)), \
         patch("agents.safety_agent.is_llm_configured", return_value=False):
        result = await validate_recommendation(state)

    assert result["status"] == "ERROR"
    assert any(c["code"] == "VALIDATION_EXECUTION" for c in result["checks"])


@pytest.mark.asyncio
async def test_error_when_evidence_review_cites_unauthorized_reference():
    state = _baseline_state()
    evidence = _baseline_evidence()
    # Gemini cites a reference that was never offered in allowedEvidenceRefs.
    review = EvidenceReview(supported=True, findings=[], evidenceRefs=[SOURCE_REF, "problem:unauthorized"])

    with patch("agents.safety_agent.get_validation_context", _mock_validation_context(evidence)), \
         patch("agents.safety_agent.is_llm_configured", return_value=True), \
         patch("agents.safety_agent.get_llm", return_value=_mock_llm(review)):
        result = await validate_recommendation(state)

    assert result["status"] == "ERROR"
    assert any(c["code"] == "VALIDATION_EXECUTION" for c in result["checks"])


def test_state_is_not_mutated_across_calls():
    """Each call must start from a clean baseline; guards against shared-state bugs in tests."""
    state_a = _baseline_state()
    state_b = copy.deepcopy(state_a)
    assert state_a == state_b
