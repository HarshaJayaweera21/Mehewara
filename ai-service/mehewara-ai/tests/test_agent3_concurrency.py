"""
Mehewara AI Service — Concurrency Isolation Tests for Agent 3

Verifies that the coroutine-isolated ContextVar mechanism in tools/crew_tools.py
prevents state contamination between concurrent async workflows running on the event loop.
"""

from __future__ import annotations

import asyncio
from uuid import uuid4
import pytest

from tools.crew_tools import (
    check_crew_availability,
    get_crew_capabilities,
    reset_workflow_crew_context,
    set_workflow_crew_context,
)
from agents.priority_crew_agent import run_priority_recommendation
from unittest.mock import patch


@pytest.mark.asyncio
async def test_concurrent_crew_contexts_isolation():
    """
    Test that concurrent coroutines executing on the asyncio event loop
    maintain completely isolated crew contexts via ContextVar, preventing
    cross-talk or race conditions.
    """
    async def worker_depot(depot_name: str, crew_type: str, crew_count: int):
        # Generate depot-specific crew records
        crews = [
            {
                "crewId": f"{depot_name}-crew-{i}",
                "name": f"{depot_name} Crew {i}",
                "crewType": crew_type,
                "status": "AVAILABLE",
                "activeWorkOrderId": None,
            }
            for i in range(crew_count)
        ]

        token = set_workflow_crew_context(crews)
        try:
            # Yield control to event loop to interleave execution with other coroutines
            await asyncio.sleep(0.02)

            # Query tools
            caps = get_crew_capabilities.invoke({})
            avail = check_crew_availability.invoke({"crew_type": crew_type})

            # Assert that caps belongs strictly to this depot
            assert len(caps) == crew_count, f"{depot_name} saw {len(caps)} crews instead of {crew_count}"
            assert all(depot_name in c["name"] for c in caps), f"{depot_name} had leaking crews from another depot!"
            assert all(c["crewType"] == crew_type for c in caps)

            assert len(avail) == crew_count
            assert all(depot_name in c["name"] for c in avail)

            # Additional pause to interleave resets
            await asyncio.sleep(0.01)

            return {
                "depot": depot_name,
                "count": len(caps),
                "matched": True,
            }
        finally:
            reset_workflow_crew_context(token)

    # Launch 5 concurrent depot requests with differing crew numbers and types
    tasks = [
        worker_depot("Depot-Colombo", "ROAD", 5),
        worker_depot("Depot-Kelaniya", "DRAINAGE", 2),
        worker_depot("Depot-Kaduwela", "WASTE", 4),
        worker_depot("Depot-Dehiwala", "ELECTRICAL", 3),
        worker_depot("Depot-Moratuwa", "ENVIRONMENT", 6),
    ]

    results = await asyncio.gather(*tasks)
    assert len(results) == 5
    assert all(r["matched"] for r in results)


@pytest.mark.asyncio
async def test_concurrent_run_priority_recommendation():
    """
    Verify run_priority_recommendation handles concurrent invocations with distinct
    available_crews lists cleanly (using deterministic fallback).
    """
    async def run_req(req_id: int, cat: str):
        crews = [
            {
                "crewId": f"crew-{req_id}",
                "name": f"Specialized {cat} Team {req_id}",
                "crewType": cat,
                "status": "AVAILABLE",
                "activeWorkOrderId": None,
            }
        ]
        prob = {
            "problemId": str(uuid4()),
            "title": f"Test Problem {req_id} for {cat}",
            "description": f"Urgent municipal defect for {cat}",
            "category": cat,
            "reportCount": 2,
        }

        # Force offline deterministic fallback
        with patch("agents.priority_crew_agent.is_llm_configured", return_value=False):
            res = await run_priority_recommendation(
                problem_data=prob,
                structured_report=None,
                available_crews=crews,
            )
            assert res.required_crew_type.value == cat
            assert res.recommended_crew_id == f"crew-{req_id}"
            assert f"Team {req_id}" in (res.recommended_crew_name or "")
            return True

    results = await asyncio.gather(
        run_req(1, "DRAINAGE"),
        run_req(2, "ROAD"),
        run_req(3, "ELECTRICAL"),
        run_req(4, "WASTE"),
    )
    assert all(results)
