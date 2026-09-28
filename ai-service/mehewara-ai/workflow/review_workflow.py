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
    selected = next((p for p in candidates if p.get("problemId") == problem.get("problemId")), None)
    if not selected:
        return {"error": "Established Problem context is missing", "priority_analysis": None}
    result = await run_priority_recommendation(selected, state.get("structured_report"),
        state.get("available_crews", []), validation_feedback=state.get("validation_feedback"))
    return {"priority_analysis": result.model_dump(by_alias=True)}


def review_graph(regeneration: bool):
    graph = StateGraph(MehewaraWorkflowState)
    graph.add_node("agent_4_validation", agent_4_validation_node)
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
        raw_report=request.report.model_dump(by_alias=True, mode="json"),
        candidate_problems=request.context.candidate_problems,
        related_reports=request.context.related_reports, available_crews=request.context.available_crews,
        structured_report=payload.get("reportAnalysis"), problem_analysis=payload.get("problemAnalysis"),
        priority_analysis=payload.get("priorityAnalysis"), coordinator_feedback=payload.get("coordinatorFeedback"),
        validation_feedback=build_validation_feedback(payload))
    result = await review_graph(payload.get("kind") == "REGENERATE").ainvoke(state)
    return {"priorityAnalysis": result.get("priority_analysis"), "safetyValidation": result.get("safety_validation")}
