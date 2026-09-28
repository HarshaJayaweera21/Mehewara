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

    internal static void SetReviewProgress(WorkflowRun run, WorkflowEvent? rec, string progress,
        string? attentionReason = null, AiReviewJob? job = null)
    {
        run.StateData = ReviewMetadataJson.Write(run.StateData, new WorkflowReviewMetadata {
            SchemaVersion = ReviewMetadataJson.CurrentVersion,
            RecommendationId = rec?.WorkflowEventId, Revision = rec?.Revision,
            JobId = job?.Id, ChainId = ReviewMetadataJson.Read<ReviewJobMetadata>(job?.InputData)?.ChainId,
            Progress = progress, AttentionReason = attentionReason, UpdatedAt = DateTimeOffset.UtcNow });
    }

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
        var job = jobId.HasValue ? await db.AiReviewJobs.SingleAsync(j => j.Id == jobId.Value) : null;
        ev.InputData = ReviewMetadataJson.Write(ev.InputData, new ValidationReviewMetadata {
            SchemaVersion = ReviewMetadataJson.CurrentVersion, RecommendationId = rec?.WorkflowEventId,
            Revision = rec?.Revision, JobId = jobId,
            ChainId = ReviewMetadataJson.Read<ReviewJobMetadata>(job?.InputData)?.ChainId,
            WorkerAttempt = job?.Attempts });
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
        var boundValidation = status == "VALID" && rec != null && rec.ValidatedRevision == rec.Revision;
        var issues = string.Join("; ", (validation["issues"] as JsonArray ?? new()).Select(Text));
        SetReviewProgress(run, rec, boundValidation ? "VALIDATED" : "NEEDS_ATTENTION",
            boundValidation ? null : string.IsNullOrWhiteSpace(issues)
                ? "Validation is incomplete or evidence could not be bound to this revision." : issues, job);
    }

    /// <summary>
    /// Step 3: Save Agents 1–3 outputs and queue Agent 4 validation atomically.
    /// The Python graph now ends after Agent 3; validation always starts as NOT_RUN.
    /// A VALIDATE job is inserted so the background worker runs Agent 4 independently.
    /// Repeated calls for the same workflow are idempotent (existing events guard).
    /// </summary>
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
        // Agent 4 has NOT run in the initial graph. Any safetyValidation from Python is
        // a placeholder (status: NOT_RUN). Force NOT_RUN unconditionally so that only
        // the durable background worker can produce a real validation result.
        var validation = Failure("Agent 4 validation is queued.", "NOT_RUN");
        if (analysis != null) Record(run, "REPORT_ANALYSIS", "Report Analysis Agent", analysis);
        if (consolidation != null) Record(run, "PROBLEM_CONSOLIDATION", "Problem Consolidation Agent", consolidation);
        var ids = (consolidation?["relatedReportIds"] as JsonArray ?? new()).Select(Id).Where(i => i.HasValue).Select(i => i!.Value).ToList();
        var request = new ValidationContextRequest { WorkflowId = runId, ReportIds = ids,
            ProblemId = Id(consolidation?["problemId"]), CrewId = Id(recRaw?["recommendedCrewId"]) };
        // Hold evidence rows stable while saving the initial recommendation.
        if (request.ProblemId.HasValue)
            await db.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {request.ProblemId.Value} FOR UPDATE").ToListAsync();
        if (request.CrewId.HasValue)
            await db.Crews.FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {request.CrewId.Value} FOR UPDATE").ToListAsync();
        var evidenceIds = ids.Append(run.ReportId).Distinct().ToArray();
        await db.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE report_id = ANY({evidenceIds}) ORDER BY report_id FOR UPDATE").ToListAsync();
        // No inline evidence-hash binding — validation is NOT_RUN; Agent 4 will do this.
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
        AiReviewJob? initialJob = null;
        if (recRaw != null && problem != null)
        {
            rec = Record(run, "PRIORITIZATION", "Priority & Crew Recommendation Agent", NormalizeRecommendation(recRaw, problem.ProblemId));
            rec.OriginalOutputData = recRaw.ToJsonString(Json);
            rec.InputData = ReviewMetadataJson.Write(rec.InputData, new RecommendationReviewMetadata {
                SchemaVersion = ReviewMetadataJson.CurrentVersion, Origin = ReviewOrigins.AiGenerated,
                Revision = rec.Revision });
            run.CurrentRecommendationId = rec.WorkflowEventId;
            request.ProblemId = problem.ProblemId;
            // Preserve Agent 3's repair estimate independently of Agent 4's validation outcome.
            if (recRaw["estimatedDurationMinutes"] is JsonValue durationValue &&
                durationValue.TryGetValue<int>(out var duration) && duration is >= 10 and <= 2880)
            {
                problem.EstimatedDurationMinutes = duration;
            }
            // Problem priority/status are NOT updated here. That only happens after Agent 4
            // validates the recommendation (in FinishAsync). At this point validation is NOT_RUN.

            // --- Step 3: Insert the initial VALIDATE job ---
            // Use a deterministic request ID derived from the workflow run to prevent duplicates
            // if this method is called more than once for the same workflow.
            var requestId = new Guid(System.Security.Cryptography.MD5.HashData(
                System.Text.Encoding.UTF8.GetBytes($"initial-validate-{runId}")));
            initialJob = new AiReviewJob {
                Id = Guid.NewGuid(), WorkflowRunId = runId, RecommendationId = rec.WorkflowEventId,
                ExpectedRevision = rec.Revision, RequestId = requestId,
                // Per plan: automatic initial jobs reference the report's initiating resident.
                // This identifies the initiating user, not a resident approval or admin action.
                RequestedBy = report.ResidentId,
                Kind = "VALIDATE", Reason = "Initial Agent 4 validation after Agents 1–3.",
                Status = "QUEUED", Attempts = 0 };
            initialJob.InputData = ReviewMetadataJson.Write(
                new JsonObject { ["previousValidation"] = validation.DeepClone() }.ToJsonString(Json),
                new ReviewJobMetadata {
                    SchemaVersion = ReviewMetadataJson.CurrentVersion, ChainId = initialJob.Id,
                    Origin = ReviewOrigins.System, CorrectionCount = 0 });
            db.AiReviewJobs.Add(initialJob);
        }
        run.StateData = response;
        // Set workflow status to reflect queued validation rather than completed.
        run.Status = rec != null ? "RUNNING" : "WAITING";
        run.CurrentStage = rec != null ? "VALIDATION" : (consolidation != null ? "PROBLEM_CONSOLIDATION" : "REPORT_ANALYSIS");
        run.CompletedAt = null;
        await db.SaveChangesAsync(); // Resolve new Problem/report links before recording validation.
        // Record the NOT_RUN validation event for visibility. The real validation will be
        // recorded by the worker when it executes the job.
        await RecordValidationAsync(run, rec, validation, request);
        // Set review tracking to QUEUED so the dashboard shows this workflow as processing.
        if (rec != null)
            SetReviewProgress(run, rec, "QUEUED", job: initialJob);
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
