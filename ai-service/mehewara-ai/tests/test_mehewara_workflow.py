"""
Mehewara AI Service — Unified Multi-Agent LangGraph Workflow Tests

Validates the full multi-agent orchestration pipeline:
- LangGraph graph structure & compiled topology
- Mermaid diagram generation for documentation and viva presentation
- Offline execution with mocked agent stages (no live API key needed)
- Preservation of Member 1's backward compatibility output contract
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4
import pytest

from schemas.problem_consolidation import ConsolidationDecision, ProblemConsolidationOutputSchema
from schemas.report_analysis import MunicipalCategory, StructuredReport
from workflow.mehewara_workflow import (
    MehewaraWorkflowState,
    get_workflow_mermaid_diagram,
    mehewara_graph,
    run_mehewara_workflow,
)


def test_langgraph_topology():
    """Verify that the compiled LangGraph pipeline has the required nodes and structure."""
    graph = mehewara_graph.get_graph()
    nodes = list(graph.nodes.keys())

    assert "agent_1_report_analysis" in nodes
    assert "agent_2_problem_consolidation" in nodes
    assert "agent_3_prioritization" in nodes


def test_mermaid_diagram_generation():
    """Verify that the Mermaid diagram generator outputs valid LangGraph diagram markdown."""
    diagram = get_workflow_mermaid_diagram()
    assert "graph TD" in diagram
    assert "agent_1_report_analysis" in diagram
    assert "agent_2_problem_consolidation" in diagram
    assert "agent_3_prioritization" in diagram


@pytest.mark.asyncio
async def test_unified_workflow_mocked_execution():
    """
    Test end-to-end sequential execution through LangGraph (Agent 1 -> Agent 2 -> Output)
    using mocked LLM outputs (zero API key dependency).
    """
    w_id = uuid4()
    r_id = uuid4()
    p_id = uuid4()

    mock_raw_report = {
        "id": str(r_id),
        "description": "Flooding on Galle Road near Colombo 03",
        "category": "DRAINAGE",
        "latitude": 6.9050,
        "longitude": 79.8510,
        "address": "Galle Road, Colombo 03",
        "photos": [],
    }

    mock_agent_1_output = StructuredReport(
        reportId=r_id,
        observedIssue="Severe street flooding during heavy rain",
        affectedAsset="Road storm drainage",
        reportedImpact=["Traffic blockage"],
        duration="1 day",
        hazards=["Flash flood hazard"],
        reportedCategory="DRAINAGE",
        inferredCategory=MunicipalCategory.DRAINAGE,
        categoryConfidence=0.96,
        missingInformation=[],
        imageAvailable=False,
    )

    mock_agent_2_output = ProblemConsolidationOutputSchema(
        reportId=r_id,
        decision=ConsolidationDecision.LINK_EXISTING,
        problemId=p_id,
        relatedReportIds=[r_id],
        summary="Linked to active storm drain issue P001 on Galle Road",
        evidence=["Matching DRAINAGE category", "Within 30m of existing culvert problem"],
    )

    with patch(
        "workflow.mehewara_workflow.analyze_report_with_llm",
        new=AsyncMock(return_value=mock_agent_1_output),
    ), patch(
        "workflow.mehewara_workflow.consolidate_problem_with_agent",
        new=AsyncMock(return_value=mock_agent_2_output),
    ):
        result = await run_mehewara_workflow(
            workflow_id=w_id,
            raw_report_dict=mock_raw_report,
            candidate_problems=[{"problemId": str(p_id), "category": "DRAINAGE"}],
            related_reports=[],
        )

        assert result["status"] == "completed"
        assert result["workflow_id"] == str(w_id)

        # Stage 1 output present
        assert result["report_analysis"] is not None
        assert result["report_analysis"]["observedIssue"] == "Severe street flooding during heavy rain"

        # Stage 2 output present
        assert result["problem_analysis"] is not None
        assert result["problem_analysis"]["decision"] == "LINK_EXISTING"
        assert str(result["problem_analysis"]["problemId"]) == str(p_id)

        # Stage 3 output present
        assert result["priority_analysis"] is not None
        assert result["priority_analysis"]["priority"] is not None
        assert "recommendations" in result
        assert len(result["recommendations"]) > 0

        # Backward compatibility alias for Member 1 ASP.NET Core client
        assert result["analysis"] is not None
        assert result["analysis"]["inferredCategory"] == "DRAINAGE"
