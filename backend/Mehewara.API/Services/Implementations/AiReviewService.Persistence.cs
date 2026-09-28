using System.Text.Json;
using System.Text.Json.Nodes;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class AiReviewService
{
    internal static JsonObject NormalizeRecommendation(JsonObject raw, Guid problemId)
    {
        var normalized = raw.DeepClone().AsObject();
        normalized["problemId"] = problemId.ToString();
        normalized["recommendedCrewId"] = Id(raw["recommendedCrewId"])?.ToString();
        return normalized;
    }

    internal static JsonObject Failure(string message, string status = "ERROR") => new()
    {
        ["status"] = status, ["issues"] = new JsonArray(JsonValue.Create(message)),
        ["policyVersion"] = "agent4-v1"
    };

    private WorkflowEvent Record(WorkflowRun run, string stage, string agent, JsonNode? output)
    {
        var ev = new WorkflowEvent { WorkflowEventId = Guid.NewGuid(), WorkflowRunId = run.WorkflowRunId,
            WorkflowRun = run, Stage = stage, AgentName = agent, Status = "COMPLETED",
            StartedAt = DateTime.UtcNow, CompletedAt = DateTime.UtcNow, OutputData = output?.ToJsonString(Json) };
        db.WorkflowEvents.Add(ev);
        return ev;
    }

    internal async Task RecordValidationAsync(WorkflowRun run, WorkflowEvent? rec, JsonObject validation,
        ValidationContextRequest? evidenceRequest, Guid? jobId = null)
    {
        var ev = Record(run, "VALIDATION", "Validation & Safety Agent", validation);
        var status = Text(validation["status"]);
        ev.Status = status == "ERROR" ? "FAILED" : status == "NOT_RUN" ? "WAITING" : "COMPLETED";
        if (DateTimeOffset.TryParse(Text(validation["startedAt"]), out var start)) ev.StartedAt = start.UtcDateTime;
        if (DateTimeOffset.TryParse(Text(validation["completedAt"]), out var end)) ev.CompletedAt = end.UtcDateTime;
        ev.InputData = new JsonObject { ["recommendationId"] = rec?.WorkflowEventId.ToString(),
            ["revision"] = rec?.Revision, ["jobId"] = jobId?.ToString(),
            ["reviewInput"] = validation["inputData"]?.DeepClone() }.ToJsonString(Json);
        ev.ToolResults = validation["toolResults"]?.ToJsonString(Json);
        ev.ValidationResult = validation.ToJsonString(Json);
        if (rec != null)
        {
            rec.ValidationResult = validation.ToJsonString(Json);
            rec.ValidatedRevision = status == "VALID" ? rec.Revision : null;
            rec.EvidenceRequest = evidenceRequest == null ? null : JsonSerializer.Serialize(evidenceRequest, Json);
            rec.EvidenceHash = null;
            if (status == "VALID" && evidenceRequest != null)
            {
                var evidence = await LoadEvidenceAsync(evidenceRequest, run.ReportId);
                rec.EvidenceHash = Text(evidence["evidenceHash"]);
                if (evidence["complete"]?.GetValue<bool>() != true) rec.ValidatedRevision = null;
            }
        }
        run.CurrentStage = status == "VALID" ? "WAITING_FOR_APPROVAL" : "VALIDATION";
        run.Status = status == "ERROR" ? "FAILED" : "WAITING";
        run.CompletedAt = null;
        run.UpdatedAt = DateTime.UtcNow;
    }

    public async Task PersistInitialAsync(Guid runId, string response)
    {
        await using var transaction = await db.Database.BeginTransactionAsync();
        var run = await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        if (await db.WorkflowEvents.AnyAsync(e => e.WorkflowRunId == runId)) return; // Initial response is applied once.
        var report = await db.Reports.SingleAsync(r => r.ReportId == run.ReportId);
        var input = Obj(run.InputData); var result = Obj(response);
        var analysis = result["reportAnalysis"] ?? result["analysis"];
        var consolidation = result["problemAnalysis"] as JsonObject;
        var recRaw = result["priorityAnalysis"] as JsonObject;
        var validation = result["safetyValidation"] as JsonObject ?? Failure("Agent 4 result is missing.", "NOT_RUN");
        if (analysis != null) Record(run, "REPORT_ANALYSIS", "Report Analysis Agent", analysis);
        if (consolidation != null) Record(run, "PROBLEM_CONSOLIDATION", "Problem Consolidation Agent", consolidation);
        var ids = (consolidation?["relatedReportIds"] as JsonArray ?? new()).Select(Id).Where(i => i.HasValue).Select(i => i!.Value).ToList();
        var request = new ValidationContextRequest { WorkflowId = runId, ReportIds = ids,
            ProblemId = Id(consolidation?["problemId"]), CrewId = Id(recRaw?["recommendedCrewId"]) };
        // Hold evidence rows stable while verifying and binding this initial result.
        if (request.ProblemId.HasValue)
            await db.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {request.ProblemId.Value} FOR UPDATE").ToListAsync();
        if (request.CrewId.HasValue)
            await db.Crews.FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {request.CrewId.Value} FOR UPDATE").ToListAsync();
        var evidenceIds = ids.Append(run.ReportId).Distinct().ToArray();
        await db.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE report_id = ANY({evidenceIds}) ORDER BY report_id FOR UPDATE").ToListAsync();
        if (Text(validation["status"]) == "VALID")
        {
            var fresh = await GetEvidenceAsync(request);
            if (Text(fresh["evidenceHash"]) != Text(validation["evidenceHash"]))
                validation = Failure("Evidence changed during AI processing. Revalidate.", "REVISION_REQUIRED");
        }
        Problem? problem = null;
        var candidates = input["context"]?["candidateProblems"] as JsonArray ?? new();
        if (Text(consolidation?["decision"]) == "LINK_EXISTING" && request.ProblemId.HasValue &&
            candidates.Any(p => Id(p?["problemId"]) == request.ProblemId))
        {
            var pid = request.ProblemId.Value;
            problem = await db.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {pid} FOR UPDATE").SingleOrDefaultAsync();
        }
        else if (Text(consolidation?["decision"]) == "CREATE_NEW" && consolidation?["newProblem"] is JsonObject proposed &&
                 new[] { "ROAD", "DRAINAGE", "WASTE", "ELECTRICAL", "ENVIRONMENT" }.Contains(Text(proposed["category"])) &&
                 !string.IsNullOrWhiteSpace(Text(proposed["title"])))
        {
            problem = new Problem { ProblemId = Guid.NewGuid(), Title = Text(proposed["title"]),
                Description = Text(proposed["description"]), Category = Text(proposed["category"]),
                Latitude = proposed["latitude"]?.GetValue<decimal>() ?? report.Latitude,
                Longitude = proposed["longitude"]?.GetValue<decimal>() ?? report.Longitude,
                Address = Text(proposed["address"]) is { Length: > 0 } address ? address : report.Address,
                Status = "IDENTIFIED", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.Problems.Add(problem);
        }
        if (problem != null)
        {
            report.ProblemId = problem.ProblemId;
            run.ProblemId = problem.ProblemId;
            if (Text(consolidation?["decision"]) == "LINK_EXISTING")
            {
                var linked = await db.Reports.Where(r => r.ProblemId == problem.ProblemId).ToListAsync();
                if (!linked.Any(r => r.ReportId == report.ReportId)) linked.Add(report);
                problem.Latitude = linked.Average(r => r.Latitude);
                problem.Longitude = linked.Average(r => r.Longitude);
            }
            problem.UpdatedAt = DateTime.UtcNow;
            if (!string.IsNullOrWhiteSpace(Text(consolidation?["updatedProblemDescription"])))
                problem.Description = Text(consolidation!["updatedProblemDescription"]);
        }
        WorkflowEvent? rec = null;
        if (recRaw != null && problem != null)
        {
            rec = Record(run, "PRIORITIZATION", "Priority & Crew Recommendation Agent", NormalizeRecommendation(recRaw, problem.ProblemId));
            rec.OriginalOutputData = recRaw.ToJsonString(Json);
            run.CurrentRecommendationId = rec.WorkflowEventId;
            request.ProblemId = problem.ProblemId;
            // Preserve Agent 3's repair estimate independently of Agent 4's validation outcome.
            if (recRaw["estimatedDurationMinutes"] is JsonValue durationValue &&
                durationValue.TryGetValue<int>(out var duration) && duration is >= 10 and <= 2880)
            {
                problem.EstimatedDurationMinutes = duration;
            }
            if (Text(validation["status"]) == "VALID")
            {
                problem.Priority = Text(recRaw["priority"]);
                problem.PriorityScore = recRaw["priorityScore"]?.GetValue<int>();
                if (problem.Status is "IDENTIFIED" or "AWAITING_ASSIGNMENT") problem.Status = "AWAITING_ASSIGNMENT";
            }
        }
        run.StateData = response;
        await db.SaveChangesAsync(); // Resolve new Problem/report links before binding normalized evidence.
        await RecordValidationAsync(run, rec, validation, request);
        await db.SaveChangesAsync();
        await transaction.CommitAsync();
    }

    public async Task MarkInitialFailureAsync(Guid runId)
    {
        var run = await db.WorkflowRuns.SingleOrDefaultAsync(r => r.WorkflowRunId == runId);
        if (run == null) return;
        await RecordValidationAsync(run, null, Failure("AI workflow failed before a durable response was received."), null);
        await db.SaveChangesAsync();
    }
}
