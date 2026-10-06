"""
Mehewara AI Service — Unit & Integration Tests for Agent 1 (Report Analysis & Structuring)

Tests cover:
- Schema validation & constraints (ReportInputSchema, StructuredReport)
- Category normalization & synonym mapping (non-hallucination guardrail)
- reportedImpact normalization
- Tool execution (municipal asset catalog, location context, asset context)
- Deterministic category-hint keyword scan
- Cognitive report-analysis mock tests (LLM-backed golden cases)
- Safe failure handling when the LLM is not configured
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from schemas.report_analysis import MunicipalCategory, ReportInputSchema, StructuredReport
from tools.report_tools import (
    analyze_category_hints,
    get_asset_context,
    get_location_context,
    get_municipal_asset_catalog,
)
from agents.report_agent import analyze_report_with_llm


# ────────────────────────────────────────────────────────────────
# 1. Schemas & Constraints Tests
# ────────────────────────────────────────────────────────────────

def test_report_input_schema_creation():
    """Test valid construction of ReportInputSchema."""
    r_id = uuid4()
    payload = ReportInputSchema(
        id=r_id,
        description="Large pothole in the center lane with visible asphalt crumbling",
        category="ROAD",
        latitude=6.9271,
        longitude=79.8612,
        address="Main Street, Colombo 11",
    )
    assert payload.id == r_id
    assert payload.category == "ROAD"
    assert payload.photos == []


def test_report_input_schema_rejects_description_shorter_than_min_length():
    """Description must be at least 10 characters to provide sufficient detail."""
    with pytest.raises(ValueError):
        ReportInputSchema(
            id=uuid4(),
            description="too short",
            category="ROAD",
            latitude=6.9271,
            longitude=79.8612,
        )


def test_report_input_schema_rejects_coordinates_out_of_range():
    """Latitude/longitude must stay within valid geographic bounds."""
    with pytest.raises(ValueError):
        ReportInputSchema(
            id=uuid4(),
            description="Pothole on the road causing damage to vehicles",
            category="ROAD",
            latitude=120.0,
            longitude=79.8612,
        )


def test_structured_report_category_normalization_maps_known_synonyms():
    """Synonym keywords (e.g. 'POTHOLE', 'DRAIN') must map to the correct MunicipalCategory."""
    r_id = uuid4()
    report = StructuredReport(
        reportId=r_id,
        observedIssue="Deep pothole",
        affectedAsset="road surface",
        reportedCategory="ROAD",
        inferredCategory="POTHOLE",
        categoryConfidence=0.9,
    )
    assert report.inferred_category == MunicipalCategory.ROAD


def test_structured_report_category_normalization_falls_back_to_environment():
    """An unrecognized category string must fall back to ENVIRONMENT rather than erroring."""
    r_id = uuid4()
    report = StructuredReport(
        reportId=r_id,
        observedIssue="Unclear issue",
        affectedAsset="unknown asset",
        reportedCategory="MYSTERY",
        inferredCategory="MYSTERY",
        categoryConfidence=0.3,
    )
    assert report.inferred_category == MunicipalCategory.ENVIRONMENT


def test_structured_report_reported_impact_normalizes_none_to_empty_list():
    """A null reportedImpact must normalize to an empty list, not None."""
    report = StructuredReport(
        reportId=uuid4(),
        observedIssue="Streetlight out",
        affectedAsset="street light pole",
        reportedImpact=None,
        reportedCategory="ELECTRICAL",
        inferredCategory="ELECTRICAL",
        categoryConfidence=0.8,
    )
    assert report.reported_impact == []


def test_structured_report_reported_impact_normalizes_single_string_to_list():
    """A bare string reportedImpact must be wrapped into a single-element list."""
    report = StructuredReport(
        reportId=uuid4(),
        observedIssue="Overflowing bin",
        affectedAsset="communal dumpster",
        reportedImpact="Foul smell affecting nearby residents",
        reportedCategory="WASTE",
        inferredCategory="WASTE",
        categoryConfidence=0.85,
    )
    assert report.reported_impact == ["Foul smell affecting nearby residents"]


def test_structured_report_rejects_confidence_outside_zero_to_one():
    """categoryConfidence must stay within the 0.0 to 1.0 bound."""
    with pytest.raises(ValueError):
        StructuredReport(
            reportId=uuid4(),
            observedIssue="Pothole",
            affectedAsset="road surface",
            reportedCategory="ROAD",
            inferredCategory="ROAD",
            categoryConfidence=1.5,
        )


# ────────────────────────────────────────────────────────────────
# 2. Tool Unit Tests
# ────────────────────────────────────────────────────────────────

def test_get_municipal_asset_catalog_returns_category_specific_assets():
    """Requesting a known category must return only that category's assets."""
    assets = get_municipal_asset_catalog.invoke({"category": "DRAINAGE"})
    assert "stormwater drain" in assets
    assert "street light pole / luminaire" not in assets


def test_get_municipal_asset_catalog_returns_all_assets_when_no_category_given():
    """Omitting the category must return the full combined municipal asset catalog."""
    assets = get_municipal_asset_catalog.invoke({})
    assert "stormwater drain" in assets
    assert "street light pole / luminaire" in assets
    assert "roadside tree / overgrown branches" in assets


def test_get_location_context_uses_fallback_address_when_unspecified():
    """Missing address must fall back to an explicit 'not specified' marker, never a guess."""
    context = get_location_context.invoke({"latitude": 6.9271, "longitude": 79.8612, "address": None})
    assert context["address"] == "Address not specified by resident"
    assert context["latitude"] == 6.9271


def test_get_asset_context_returns_valid_assets_and_coordinates():
    """get_asset_context must combine the asset catalog lookup with the given coordinates."""
    context = get_asset_context.invoke({"category": "road", "latitude": 6.9271, "longitude": 79.8612})
    assert context["category"] == "ROAD"
    assert "road surface" in context["valid_assets"]
    assert context["coordinates"] == {"lat": 6.9271, "lng": 79.8612}


# ────────────────────────────────────────────────────────────────
# 3. Deterministic Category-Hint Tests
# ────────────────────────────────────────────────────────────────

def test_analyze_category_hints_detects_road_keywords():
    """A description mentioning road-related keywords should score ROAD highest."""
    category, confidence = analyze_category_hints("There is a deep pothole on the asphalt road")
    assert category == "ROAD"
    assert confidence > 0.6


def test_analyze_category_hints_falls_back_to_environment_with_no_keywords():
    """A description with no recognizable keywords must default to ENVIRONMENT at 0.50 confidence."""
    category, confidence = analyze_category_hints("Something is wrong here")
    assert category == "ENVIRONMENT"
    assert confidence == 0.50


# ────────────────────────────────────────────────────────────────
# 4. Cognitive Report Analysis Mock Tests
# ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_analyze_report_with_llm_raises_when_llm_not_configured():
    """Agent 1 must fail safely with a clear error when no LLM is configured, never silently guess."""
    report_input = ReportInputSchema(
        id=uuid4(),
        description="Large pothole in the center lane of the road",
        category="ROAD",
        latitude=6.9271,
        longitude=79.8612,
    )

    with patch("agents.report_agent.is_llm_configured", return_value=False):
        with pytest.raises(RuntimeError):
            await analyze_report_with_llm(report_input)


@pytest.mark.asyncio
async def test_analyze_report_with_llm_populates_report_id_and_image_available_from_input():
    """The returned StructuredReport must always carry the input's report id and photo-derived imageAvailable flag."""
    r_id = uuid4()
    report_input = ReportInputSchema(
        id=r_id,
        description="Streetlight has been broken for three days near the junction",
        category="ELECTRICAL",
        latitude=6.9271,
        longitude=79.8612,
        photos=[],
    )

    mock_output = StructuredReport(
        reportId=uuid4(),  # deliberately different; agent must overwrite with input's id
        observedIssue="Broken streetlight",
        affectedAsset="street light pole",
        reportedImpact=["Dark intersection at night"],
        duration="3 days",
        hazards=["pedestrian safety risk"],
        reportedCategory="ELECTRICAL",
        inferredCategory=MunicipalCategory.ELECTRICAL,
        categoryConfidence=0.9,
        missingInformation=[],
        imageAvailable=True,  # deliberately wrong; agent must overwrite based on input.photos
    )

    with patch("agents.report_agent.is_llm_configured", return_value=True), patch("agents.report_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_output)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await analyze_report_with_llm(report_input)

        assert result.report_id == r_id
        assert result.image_available is False
        assert result.inferred_category == MunicipalCategory.ELECTRICAL


@pytest.mark.asyncio
async def test_analyze_report_with_llm_preserves_missing_information_gaps():
    """Agent 1 must preserve unstated details as explicit missingInformation entries, not invented facts."""
    r_id = uuid4()
    report_input = ReportInputSchema(
        id=r_id,
        description="Water is pooling on the road surface near the bus stand",
        category="DRAINAGE",
        latitude=6.9271,
        longitude=79.8612,
    )

    mock_output = StructuredReport(
        reportId=r_id,
        observedIssue="Water accumulation on road surface",
        affectedAsset="road surface",
        reportedImpact=[],
        duration=None,
        hazards=[],
        reportedCategory="DRAINAGE",
        inferredCategory=MunicipalCategory.DRAINAGE,
        categoryConfidence=0.7,
        missingInformation=["duration unstated", "no photos provided"],
        imageAvailable=False,
    )

    with patch("agents.report_agent.is_llm_configured", return_value=True), patch("agents.report_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_output)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await analyze_report_with_llm(report_input)

        assert "duration unstated" in result.missing_information
        assert "no photos provided" in result.missing_information
        assert result.duration is None


@pytest.mark.asyncio
async def test_analyze_report_with_llm_accepts_dict_result_and_coerces_to_schema():
    """If the LLM backend returns a raw dict instead of a StructuredReport instance, it must still be coerced safely."""
    r_id = uuid4()
    report_input = ReportInputSchema(
        id=r_id,
        description="Overflowing garbage bin attracting pests near the market",
        category="WASTE",
        latitude=6.9271,
        longitude=79.8612,
        photos=[],
    )

    mock_dict_result = {
        "observedIssue": "Overflowing garbage bin",
        "affectedAsset": "communal dumpster",
        "reportedImpact": ["pest infestation risk"],
        "duration": None,
        "hazards": ["health hazard"],
        "reportedCategory": "WASTE",
        "inferredCategory": "WASTE",
        "categoryConfidence": 0.88,
        "missingInformation": [],
    }

    with patch("agents.report_agent.is_llm_configured", return_value=True), patch("agents.report_agent.get_llm") as mock_get_llm:
        mock_structured_llm = MagicMock()
        mock_structured_llm.ainvoke = AsyncMock(return_value=mock_dict_result)
        mock_llm_instance = MagicMock()
        mock_llm_instance.with_structured_output.return_value = mock_structured_llm
        mock_get_llm.return_value = mock_llm_instance

        result = await analyze_report_with_llm(report_input)

        assert isinstance(result, StructuredReport)
        assert result.report_id == r_id
        assert result.inferred_category == MunicipalCategory.WASTE
