"""
Mehewara AI Service — Allow-Listed Tools for Agent 1

Provides least-privilege context tools decorated with LangChain `@tool` for Agent 1
(Report Analysis & Structuring):
- Municipal asset catalog lookup (prevents asset hallucination)
- Location & spatial context formatting
- Authoritative municipal category guidelines
"""

from __future__ import annotations

from typing import Any
from langchain_core.tools import tool

# Authoritative catalog of municipal assets categorized by municipal department
MUNICIPAL_ASSET_CATALOG: dict[str, list[str]] = {
    "ROAD": [
        "road surface",
        "asphalt pavement",
        "sidewalk / footway",
        "curb / gutter",
        "speed breaker / hump",
        "road marking / zebra crossing",
        "traffic sign / signal post",
        "guardrail / crash barrier",
        "manhole cover",
        "bridge / culvert roadway deck",
    ],
    "DRAINAGE": [
        "stormwater drain",
        "side ditch / open canal",
        "drainage culvert",
        "catch basin / gully pit",
        "retention basin",
        "sewer inlet / grating",
        "outfall pipe",
    ],
    "WASTE": [
        "public litter bin",
        "communal dumpster / waste skip",
        "street side waste collection point",
        "recycling drop-off station",
        "roadside illegal dump site",
    ],
    "ELECTRICAL": [
        "street light pole / luminaire",
        "distribution pole",
        "overhead power line / cable",
        "transformer enclosure / kiosk",
        "traffic light control box",
        "public junction box",
    ],
    "ENVIRONMENT": [
        "roadside tree / overgrown branches",
        "public park / green space",
        "storm-damaged tree / fallen trunk",
        "waterway bank / slope",
        "air / noise emission source",
    ],
}

CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "ROAD": ["pothole", "asphalt", "tar", "crack", "crater", "road", "street", "pavement", "curb", "sidewalk", "divider"],
    "DRAINAGE": ["drain", "drainage", "flood", "waterlogging", "culvert", "overflowing water", "clogged drain", "stormwater", "canal", "gutter"],
    "WASTE": ["garbage", "trash", "waste", "refuse", "dump", "bin", "litter", "debris", "rotting", "foul smell", "plastics"],
    "ELECTRICAL": ["street light", "streetlight", "wire", "cable", "spark", "blackout", "pole", "light bulb", "transformer", "electrocution", "power"],
    "ENVIRONMENT": ["tree", "branch", "fallen tree", "overgrown", "grass", "soil erosion", "bank collapse", "park", "foliage"],
}


@tool
def get_municipal_asset_catalog(category: str | None = None) -> list[str]:
    """Retrieve the standard list of municipal infrastructure assets for a category.
    
    Use this tool to choose official municipal terminology (e.g. 'road surface', 'stormwater drain',
    'street light pole') rather than guessing or hallucinating non-standard asset names.
    
    Args:
        category: Optional category name ('ROAD', 'DRAINAGE', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT').
    """
    if category and category.upper() in MUNICIPAL_ASSET_CATALOG:
        return MUNICIPAL_ASSET_CATALOG[category.upper()]

    # Return all standard assets combined
    all_assets: list[str] = []
    for assets in MUNICIPAL_ASSET_CATALOG.values():
        all_assets.extend(assets)
    return all_assets


@tool
def get_location_context(latitude: float, longitude: float, address: str | None = None) -> dict[str, str | float | None]:
    """Format and validate geographic location context and address metadata for a report.
    
    Args:
        latitude: Geographic latitude coordinate (-90.0 to 90.0).
        longitude: Geographic longitude coordinate (-180.0 to 180.0).
        address: Optional reverse-geocoded street address or neighborhood.
    """
    return {
        "latitude": latitude,
        "longitude": longitude,
        "address": address or "Address not specified by resident",
    }


@tool
def get_asset_context(category: str, latitude: float, longitude: float) -> dict[str, Any]:
    """Lookup standard municipal infrastructure assets and spatial classification for a category and coordinate.
    
    Args:
        category: The municipal category ('ROAD', 'DRAINAGE', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT').
        latitude: Geographic latitude coordinate.
        longitude: Geographic longitude coordinate.
    """
    assets = get_municipal_asset_catalog.invoke({"category": category})
    return {
        "category": category.upper(),
        "valid_assets": assets,
        "coordinates": {"lat": latitude, "lng": longitude},
    }


def analyze_category_hints(description: str) -> tuple[str, float]:
    """
    Deterministic rule-based keyword scan to assist category classification.
    Returns (suggested_category, confidence_hint).
    """
    desc_lower = description.lower()
    matches: dict[str, int] = {cat: 0 for cat in CATEGORY_KEYWORDS}

    for cat, keywords in CATEGORY_KEYWORDS.items():
        for kw in keywords:
            if kw in desc_lower:
                matches[cat] += 1

    sorted_matches = sorted(matches.items(), key=lambda x: x[1], reverse=True)
    top_cat, top_score = sorted_matches[0]

    if top_score > 0:
        confidence = min(0.60 + (top_score * 0.15), 0.98)
        return top_cat, round(confidence, 2)

    return "ENVIRONMENT", 0.50


# List of allow-listed LangChain tools exported for Agent 1
AGENT_1_TOOLS = [
    get_municipal_asset_catalog,
    get_location_context,
    get_asset_context,
]
