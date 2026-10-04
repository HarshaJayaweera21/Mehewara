"""Small reusable review graph; the original Agent 1/2 path stays intact."""
from langgraph.graph import END, StateGraph
from uuid import UUID
from agents.priority_crew_agent import run_priority_recommendation
from api.models import WorkflowTriggerRequest
from workflow.mehewara_workflow import MehewaraWorkflowState, agent_4_validation_node


def build_validation_feedback(payload: dict) -> dict:
    """Adapt saved review findings and attributed coordinator guidance for Agent 3."""
    previous = payload.get("previousValidation") or {}
    feedback = dict(payload.get("validationFeedback") or {})
    issues = list(dict.fromkeys([*previous.get("issues", []), *feedback.get("issues", [])]))
    corrections = [f["correction"] for f in previous.get("findings", []) if f.get("correction")]
    rejected = list(feedback.get("rejected_crew_ids", []))
    if any(c.get("passed") is False and c.get("code") in ("SPECIALTY", "CREW_AVAILABLE")
           for c in previous.get("checks", [])):
        crew_id = (payload.get("priorityAnalysis") or {}).get("recommendedCrewId")
        if crew_id:
            rejected.append(crew_id)
    crew_ids = []
    for value in rejected:
        try:
            crew_ids.append(str(UUID(str(value))))
        except (ValueError, TypeError, AttributeError):
            continue  # Sentinels such as NONE are not crew identifiers.
    status = feedback.get("status") or previous.get("status", "NOT_RUN")
    feedback.update(
        status="REVISION_REQUIRED" if status in ("INVALID", "REVISION_REQUIRED") else status,
        retry_count=feedback.get("retry_count", 1),
        rejected_crew_ids=list(dict.fromkeys(crew_ids)), issues=issues,
        suggested_action=feedback.get("suggested_action") or "\n".join(corrections),
        coordinator_reason=payload.get("coordinatorFeedback") or feedback.get("coordinator_reason", ""),
    )
    return feedback


async def regenerate(state: MehewaraWorkflowState) -> dict:
    problem = state["problem_analysis"]
    candidates = state.get("candidate_problems", [])
    pid = state.get("resolved_problem_id") or problem.get("problemId")
    selected = next((p for p in candidates if p.get("problemId") == pid), None)
    if not selected:
        return {"error": "Established Problem context is missing", "priority_analysis": None}
    rejected = set((state.get("validation_feedback") or {}).get("rejected_crew_ids", []))
    roster = [c for c in state.get("available_crews", []) if str(c.get("crewId", "")).lower() not in rejected]
    result = await run_priority_recommendation(selected, state.get("structured_report"),
        roster, validation_feedback=state.get("validation_feedback"))
    return {"priority_analysis": result.model_dump(by_alias=True), "available_crews": roster}


async def review_with_exclusions(state: MehewaraWorkflowState) -> dict:
    result = await agent_4_validation_node(state)
    review = result["safety_validation"]
    recommendation = state.get("priority_analysis") or {}
    crew = str(recommendation.get("recommendedCrewId") or "").lower()
    rejected = set((state.get("validation_feedback") or {}).get("rejected_crew_ids", []))
    if crew in rejected and review.get("status") in ("VALID", "REVISION_REQUIRED"):
        # A model must not bypass the accumulated blacklist. Keep its exact output
        # for audit and request a correction rather than silently rewriting it.
        message = "Agent 3 selected a crew excluded by an earlier validation attempt."
        review["status"] = "REVISION_REQUIRED"
        review["suggestedAction"] = "REGENERATE"
        review.setdefault("checks", []).append({"code": "REJECTED_CREW", "passed": False, "message": message})
        review.setdefault("issues", []).append(message)
        review.setdefault("findings", []).append({"code": "REJECTED_CREW", "message": message,
            "correction": "Choose a matching available crew outside rejected_crew_ids, or output NONE.", "evidenceRefs": []})
    return result


def review_graph(regeneration: bool):
    graph = StateGraph(MehewaraWorkflowState)
    graph.add_node("agent_4_validation", review_with_exclusions)
    if regeneration:
        graph.add_node("agent_3_regeneration", regenerate)
        graph.set_entry_point("agent_3_regeneration")
        graph.add_edge("agent_3_regeneration", "agent_4_validation")
    else:
        graph.set_entry_point("agent_4_validation")
    graph.add_edge("agent_4_validation", END)
    return graph.compile()


async def run_review(payload: dict) -> dict:
    request = WorkflowTriggerRequest.model_validate(payload)
    state = MehewaraWorkflowState(
        workflow_id=str(request.workflow_id), job_id=payload["jobId"],
        resolved_problem_id=payload.get("resolvedProblemId"),
        recommendation_id=payload.get("recommendationId"), recommendation_revision=payload.get("recommendationRevision"),
        review_kind=payload.get("kind"),
        authorized_report_ids=payload.get("authorizedReportIds", []),
        authorized_crew_ids=[str(c.get("crewId")) for c in request.context.available_crews],
        authorized_problem_ids=[str(p.get("problemId")) for p in request.context.candidate_problems],
        raw_report=request.report.model_dump(by_alias=True, mode="json"),
        candidate_problems=request.context.candidate_problems,
        related_reports=request.context.related_reports, available_crews=request.context.available_crews,
        structured_report=payload.get("reportAnalysis"), problem_analysis=payload.get("problemAnalysis"),
        priority_analysis=payload.get("priorityAnalysis"), coordinator_feedback=payload.get("coordinatorFeedback"),
        validation_feedback=build_validation_feedback(payload))
    result = await review_graph(payload.get("kind") == "REGENERATE").ainvoke(state)
    return {"priorityAnalysis": result.get("priority_analysis"), "safetyValidation": result.get("safety_validation")}
