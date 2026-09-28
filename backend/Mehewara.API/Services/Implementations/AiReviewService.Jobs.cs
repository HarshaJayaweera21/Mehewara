using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class AiReviewService
{
    public async Task<AiReviewJob> EnqueueAsync(Guid recommendationId, ReviewRequest request, Guid actor, string kind)
    {
        if (request.RequestId == Guid.Empty || request.ExpectedRevision < 1 || string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 4000)
            throw new BadRequestException("Request ID, expected revision and a reason (1–4000 characters) are required.");
        await using var tx = await db.Database.BeginTransactionAsync();
        var runId = await db.WorkflowEvents.Where(e => e.WorkflowEventId == recommendationId).Select(e => (Guid?)e.WorkflowRunId).FirstOrDefaultAsync()
            ?? throw new NotFoundException("Recommendation not found.", "RECOMMENDATION_NOT_FOUND");
        await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        var existing = await db.AiReviewJobs.SingleOrDefaultAsync(j => j.RequestId == request.RequestId);
        if (existing != null)
        {
            if (existing.RecommendationId != recommendationId || existing.ExpectedRevision != request.ExpectedRevision ||
                existing.RequestedBy != actor || existing.Kind != kind || existing.Reason != request.Reason.Trim())
                throw new ConflictException("Request ID was used with different input.", "REQUEST_ID_REUSED");
            await tx.CommitAsync();
            return existing;
        }
        var ev = await LockRecommendationAsync(recommendationId, request.ExpectedRevision);
        var job = new AiReviewJob { Id = Guid.NewGuid(), WorkflowRunId = runId, RecommendationId = recommendationId,
            ExpectedRevision = ev.Revision, RequestId = request.RequestId, RequestedBy = actor, Kind = kind, Reason = request.Reason.Trim() };
        var previousValidation = Obj(ev.ValidationResult);
        job.InputData = ReviewMetadataJson.Write(
            new JsonObject { ["previousValidation"] = previousValidation }.ToJsonString(Json),
            new ReviewJobMetadata {
                SchemaVersion = ReviewMetadataJson.CurrentVersion, ChainId = job.Id,
                Origin = ReviewOrigins.Coordinator, CorrectionCount = 0,
                Feedback = new ReviewFeedbackMetadata {
                    Status = Text(previousValidation["status"]) is { Length: > 0 } status ? status : "NOT_RUN",
                    Issues = (previousValidation["issues"] as JsonArray ?? new()).Select(Text).ToList(),
                    CoordinatorReason = job.Reason }
            });
        db.AiReviewJobs.Add(job);
        ev.ValidatedRevision = null;
        ev.ValidationResult = Failure("AI review is queued.", "NOT_RUN").ToJsonString(Json);
        ev.WorkflowRun.Status = "RUNNING";
        ev.WorkflowRun.CurrentStage = kind == "REGENERATE" ? "PRIORITIZATION" : "VALIDATION";
        ev.WorkflowRun.CompletedAt = null;
        SetReviewProgress(ev.WorkflowRun, ev, "QUEUED", job: job);
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return job;
    }

    public async Task<AiReviewJob?> GetJobAsync(Guid id) => await db.AiReviewJobs.AsNoTracking().SingleOrDefaultAsync(j => j.Id == id);

    public async Task<AiReviewJob?> ClaimAsync(CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var now = DateTime.UtcNow;
        var epoch = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var candidates = await db.AiReviewJobs.FromSqlInterpolated($@"SELECT * FROM ai_review_jobs
            WHERE (status = 'QUEUED' AND
                CASE WHEN input_data->'reviewMetadata'->>'nextAttemptUnixSeconds' IS NULL THEN 0
                WHEN input_data->'reviewMetadata'->>'nextAttemptUnixSeconds' ~ '^[0-9]{{1,12}}$'
                THEN (input_data->'reviewMetadata'->>'nextAttemptUnixSeconds')::bigint
                ELSE 999999999999 END <= {epoch})
                OR (status = 'RUNNING' AND lease_until < {now})
            ORDER BY created_at, id LIMIT 1 FOR UPDATE SKIP LOCKED").ToListAsync(ct);
        var job = candidates.FirstOrDefault();
        if (job == null) return null;
        if (job.Attempts >= 3)
        {
            job.Status = "RUNNING"; job.Error = "Review exhausted its attempts. Retry from the coordinator screen.";
            job.LeaseToken = Guid.NewGuid(); job.LeaseUntil = now.AddMinutes(4); job.UpdatedAt = now;
        }
        else
        {
            job.Status = "RUNNING"; job.Attempts++; job.LeaseToken = Guid.NewGuid();
            job.Error = null;
            job.LeaseUntil = now.AddMinutes(4); job.UpdatedAt = now;
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return job;
    }

    private async Task<JsonObject> BuildReviewInputAsync(AiReviewJob job)
    {
        var ev = await db.WorkflowEvents.Include(e => e.WorkflowRun).SingleAsync(e => e.WorkflowEventId == job.RecommendationId);
        if (ev.Revision != job.ExpectedRevision || ev.WorkflowRun.CurrentRecommendationId != ev.WorkflowEventId)
            throw new ConflictException("Recommendation changed before review started.", "STALE_RECOMMENDATION");
        var source = await db.Reports.Include(r => r.Photos).SingleAsync(r => r.ReportId == ev.WorkflowRun.ReportId);
        var pid = ev.WorkflowRun.ProblemId ?? throw new BadRequestException("Correct the Problem association before reviewing.");
        var problem = await db.Problems.AsNoTracking().SingleAsync(p => p.ProblemId == pid);
        if (source.ProblemId != pid) throw new BadRequestException("Source report no longer belongs to this Problem.");
        var events = await db.WorkflowEvents.AsNoTracking().Where(e => e.WorkflowRunId == job.WorkflowRunId
            && (e.Stage == "REPORT_ANALYSIS" || e.Stage == "PROBLEM_CONSOLIDATION")).OrderBy(e => e.StartedAt).ToListAsync();
        var reportAnalysis = events.LastOrDefault(e => e.Stage == "REPORT_ANALYSIS")?.OutputData;
        var problemAnalysis = events.LastOrDefault(e => e.Stage == "PROBLEM_CONSOLIDATION")?.OutputData;
        if (reportAnalysis == null || problemAnalysis == null) throw new BadRequestException("Original agent outputs are missing; restart report analysis.");
        var originalInput = Obj(ev.WorkflowRun.InputData);
        var original = originalInput["report"];
        if (original == null) throw new BadRequestException("Original report snapshot is missing; restart report analysis.");
        var originalContext = originalInput["context"] as JsonObject;
        if (originalContext?["complete"]?.GetValue<bool>() != true)
            throw new BadRequestException("Original context is incomplete or missing; restart report analysis.");
        if (Text(original["description"]) != source.Description || Text(original["category"]) != source.Category ||
            original["latitude"]?.GetValue<decimal>() != source.Latitude || original["longitude"]?.GetValue<decimal>() != source.Longitude ||
            Text(original["address"]) != (source.Address ?? ""))
            throw new BadRequestException("Source report evidence changed; rerun report analysis before recommendation review.");
        var authorizedReports = (originalContext["relatedReports"] as JsonArray ?? new())
            .Select(n => Id(n?["reportId"])).Where(i => i.HasValue).Select(i => i!.Value)
            .Append(source.ReportId).Distinct().OrderBy(i => i).ToArray();
        var related = await db.Reports.AsNoTracking().Where(r => authorizedReports.Contains(r.ReportId))
            .OrderBy(r => r.ReportId).Take(101).Select(r => new { reportId = r.ReportId, r.ProblemId, r.Description,
                r.Category, r.Latitude, r.Longitude, r.Address, r.Status, r.CreatedAt }).ToListAsync();
        if (related.Count > 100) throw new BadRequestException("Problem has more than 100 reports; review requires a larger evidence policy.");
        var uneditedAi = ev.Revision == 1 &&
            ev.OriginalOutputData != null &&
            ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData)?.Origin != ReviewOrigins.HumanOverride;
        var initialAi = uneditedAi && ev.PreviousRecommendationId == null;
        var authorizedCrews = (originalContext["availableCrews"] as JsonArray ?? new())
            .Select(n => Id(n?["crewId"])).Where(i => i.HasValue).Select(i => i!.Value).ToArray();
        var crews = await db.Crews.AsNoTracking()
            .Where(c => job.Kind == "REGENERATE" || !initialAi || authorizedCrews.Contains(c.CrewId))
            .Select(c => new { crewId = c.CrewId, name = c.CrewName, c.CrewType, c.Status,
            activeWorkOrderId = c.WorkOrders.Where(w => w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS")
                .OrderBy(w => w.WorkOrderId).Select(w => (Guid?)w.WorkOrderId).FirstOrDefault() }).ToListAsync();
        var consolidation = Obj(problemAnalysis);
        // Preserve the original proposal; supply the persisted ID separately.
        var decision = Text(consolidation["decision"]);
        if (decision == "LINK_EXISTING" && (!((originalContext["candidateProblems"] as JsonArray ?? new())
                .Any(p => Id(p?["problemId"]) == pid)) || Id(consolidation["problemId"]) != pid))
            throw new BadRequestException("Original consolidated Problem is outside the saved context or mapping.");
        var reviewRecommendation = job.Kind == "VALIDATE" && uneditedAi
            ? ev.OriginalOutputData ?? throw new BadRequestException("Original Agent 3 output is missing.") : ev.OutputData!;
        var metadata = ReviewMetadataJson.Read<ReviewJobMetadata>(job.InputData);
        var origin = metadata?.Origin;
        var previous = Obj(job.InputData)["previousValidation"] as JsonObject ?? new();
        var rejectedCrews = metadata?.Feedback?.RejectedCrewIds.ToList() ?? new List<Guid>();
        if ((previous["checks"] as JsonArray ?? new()).Any(c =>
            c?["passed"] is JsonValue value && value.TryGetValue<bool>(out var passed) && !passed &&
            Text(c?["code"]) is "SPECIALTY" or "CREW_AVAILABLE" or "REJECTED_CREW") &&
            Id(Obj(ev.OutputData)["recommendedCrewId"]) is Guid rejectedCrew)
            rejectedCrews.Add(rejectedCrew);
        // Keep all saved metadata while replacing stale execution evidence. Legacy jobs
        // without metadata retain that absence; a read must not invent an origin/chain.
        return ReviewMetadataJson.MergeExecutionContext(job.InputData, new JsonObject {
            ["workflowId"] = job.WorkflowRunId.ToString(), ["jobId"] = job.Id.ToString(), ["kind"] = job.Kind,
            ["recommendationId"] = ev.WorkflowEventId.ToString(), ["recommendationRevision"] = ev.Revision,
            ["resolvedProblemId"] = pid.ToString(), ["authorizedReportIds"] = Node(authorizedReports),
            ["report"] = original.DeepClone(), ["reportAnalysis"] = JsonNode.Parse(reportAnalysis),
            ["problemAnalysis"] = consolidation, ["priorityAnalysis"] = JsonNode.Parse(reviewRecommendation),
            ["previousValidation"] = Obj(job.InputData)["previousValidation"]?.DeepClone(),
            ["validationFeedback"] = metadata == null ? null : new JsonObject {
                ["status"] = metadata.Feedback?.Status ?? "NOT_RUN",
                ["retry_count"] = metadata.CorrectionCount,
                ["rejected_crew_ids"] = Node(rejectedCrews.Distinct().ToArray()),
                ["issues"] = Node(metadata.Feedback?.Issues ?? new()),
                ["suggested_action"] = metadata.Feedback?.SuggestedAction,
                ["coordinator_reason"] = metadata.Feedback?.CoordinatorReason },
            ["coordinatorFeedback"] = origin == ReviewOrigins.System ? null :
                metadata?.Feedback?.CoordinatorReason ?? job.Reason,
            ["context"] = new JsonObject {
                ["complete"] = related.Count == authorizedReports.Length,
                ["candidateProblems"] = Node(new[] { new { problemId = pid, problem.Title, problem.Description, problem.Category,
                    problem.Latitude, problem.Longitude, problem.Address, problem.Status, reportCount = related.Count } }),
                ["relatedReports"] = Node(related), ["availableCrews"] = Node(crews) }
        });
    }

    public async Task ExecuteAsync(AiReviewJob claimed, CancellationToken stopping)
    {
        if (claimed.Status != "RUNNING") return;
        var token = claimed.LeaseToken;
        if (claimed.Error != null) { await FinishAsync(claimed.Id, token, null, claimed.Error); return; }
        try
        {
            if (!await MarkRunningAsync(claimed.Id, token)) return;
            var input = await BuildReviewInputAsync(claimed);
            // Freeze this attempt's authorization context before Python requests evidence.
            var saved = await db.AiReviewJobs.Where(j => j.Id == claimed.Id && j.LeaseToken == token && j.Status == "RUNNING")
                .ExecuteUpdateAsync(s => s.SetProperty(j => j.InputData, input.ToJsonString(Json)), stopping);
            if (saved != 1) return;
            var secret = config["AiService:InternalApiKey"];
            if (string.IsNullOrWhiteSpace(secret)) throw new InvalidOperationException("Internal AI key is not configured.");
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(stopping);
            deadline.CancelAfter(TimeSpan.FromSeconds(120));
            using var request = new HttpRequestMessage(HttpMethod.Post, (config["AiService:BaseUrl"] ?? "http://localhost:8000").TrimEnd('/') + "/internal/ai/recommendation-review");
            request.Headers.Add("X-Internal-Api-Key", secret);
            request.Content = JsonContent.Create(input);
            using var client = clients.CreateClient("AiReview");
            using var response = await client.SendAsync(request, deadline.Token);
            response.EnsureSuccessStatusCode();
            var result = Obj(await response.Content.ReadAsStringAsync(deadline.Token));
            await FinishAsync(claimed.Id, token, result, null);
        }
        catch (OperationCanceledException) when (stopping.IsCancellationRequested) { /* lease expiry recovers on restart */ }
        catch (Exception ex)
        {
            var message = ex is BadRequestException || ex is ConflictException ? ex.Message : $"AI review failed ({ex.GetType().Name}). Check service configuration and retry.";
            db.ChangeTracker.Clear();
            var transient = ex is OperationCanceledException || ex is HttpRequestException http &&
                (http.StatusCode == null || (int)http.StatusCode == 408 || (int)http.StatusCode == 429 || (int)http.StatusCode >= 500);
            await FinishAsync(claimed.Id, token, null, message, transient);
        }
    }

    private async Task FinishAsync(Guid id, Guid? token, JsonObject? result, string? error, bool retryTransport = false)
    {
        db.ChangeTracker.Clear();
        var identity = await db.AiReviewJobs.AsNoTracking().SingleAsync(j => j.Id == id);
        await using var tx = await db.Database.BeginTransactionAsync();
        var runId = identity.WorkflowRunId;
        var run = await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        var job = await db.AiReviewJobs.FromSqlInterpolated($"SELECT * FROM ai_review_jobs WHERE id = {id} FOR UPDATE").SingleAsync();
        if (job.LeaseToken != token || job.Status != "RUNNING" || job.LeaseUntil == null || job.LeaseUntil <= DateTime.UtcNow) return;
        var ev = await db.WorkflowEvents.SingleAsync(e => e.WorkflowEventId == job.RecommendationId);
        AiReviewJob? successor = null;
        if (ev.Revision != job.ExpectedRevision || run.CurrentRecommendationId != ev.WorkflowEventId)
        {
            job.Status = "FAILED"; job.Error = "Result discarded because its recommendation changed.";
            // A stale job must not overwrite tracking for the current recommendation.
        }
        else
        {
            var validation = result?["safetyValidation"] as JsonObject ?? Failure(error ?? "Missing Agent 4 response.");
            var receivedValidation = validation.DeepClone();
            if (Text(validation["status"]) is not ("VALID" or "REVISION_REQUIRED" or "INVALID" or "ERROR" or "NOT_RUN"))
                validation = Failure("Agent 4 returned an unknown or missing status.");
            var input = Obj(job.InputData);
            var recRaw = result?["priorityAnalysis"] as JsonObject;
            // Bind passing output to the exact backend input, revision and Problem.
            var bindingMatches = recRaw != null && Text(validation["recommendationId"]) == ev.WorkflowEventId.ToString()
                && Id(input["recommendationId"]) == ev.WorkflowEventId
                && input["recommendationRevision"]?.GetValue<int>() == ev.Revision
                && validation["recommendationRevision"]?.GetValue<int>() == ev.Revision
                && JsonNode.DeepEquals(validation["inputData"]?["priority_analysis"], recRaw)
                && (job.Kind == "REGENERATE" ? Id(recRaw["problemId"]) == run.ProblemId :
                    JsonNode.DeepEquals(recRaw, input["priorityAnalysis"]) && run.ProblemId.HasValue &&
                    JsonNode.DeepEquals(NormalizeRecommendation(recRaw, run.ProblemId.Value), Obj(ev.OutputData)));
            if (Text(validation["status"]) == "VALID" && (!bindingMatches || !HasPassingReviewEnvelope(validation, run.ReportId)
                || !Id(recRaw?["recommendedCrewId"]).HasValue))
                validation = Failure("Review does not match the exact recommendation input/revision. Retry validation.");
            if (Text(validation["status"]) == "VALID" && Id(recRaw?["recommendedCrewId"]) is Guid selectedCrew &&
                (input["validationFeedback"]?["rejected_crew_ids"] as JsonArray ?? new()).Any(n => Id(n) == selectedCrew))
            {
                const string message = "Review selected a crew excluded by an earlier validation attempt.";
                validation["status"] = "REVISION_REQUIRED";
                validation["suggestedAction"] = "REGENERATE";
                validation["issues"]!.AsArray().Add(message);
                validation["checks"]!.AsArray().Add(new JsonObject { ["code"] = "REJECTED_CREW", ["passed"] = false, ["message"] = message });
                validation["findings"]!.AsArray().Add(new JsonObject { ["code"] = "REJECTED_CREW", ["message"] = message,
                    ["correction"] = "Select a matching available crew outside the accumulated exclusions, or return NONE.", ["evidenceRefs"] = new JsonArray() });
            }
            var request = new ValidationContextRequest { WorkflowId = runId, JobId = id, ProblemId = run.ProblemId,
                CrewId = Id(recRaw?["recommendedCrewId"] ?? Obj(ev.OutputData)["recommendedCrewId"]),
                ReportIds = (input["problemAnalysis"]?["relatedReportIds"] as JsonArray ?? new()).Select(Id).Where(x => x.HasValue).Select(x => x!.Value).ToList() };
            if (request.ProblemId.HasValue)
                await db.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {request.ProblemId.Value} FOR UPDATE").ToListAsync();
            if (request.CrewId.HasValue)
                await db.Crews.FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {request.CrewId.Value} FOR UPDATE").ToListAsync();
            var evidenceIds = request.ReportIds.Append(run.ReportId).Distinct().ToArray();
            await db.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE report_id = ANY({evidenceIds}) ORDER BY report_id FOR UPDATE").ToListAsync();
            // RecordValidationAsync performs the single fresh evidence comparison
            // under these locks; avoid fetching the same evidence twice.
            if (!JsonNode.DeepEquals(receivedValidation, validation))
                validation["agentReview"] = receivedValidation;
            var technicalFailure = error != null || recRaw == null || Text(validation["status"]) is "ERROR" or "NOT_RUN" ||
                job.Kind == "REGENERATE" && (Text(validation["status"]) == "INVALID" || !bindingMatches);
            var target = ev;
            if (job.Kind == "REGENERATE" && !technicalFailure && run.ProblemId.HasValue)
            {
                target = Record(run, "PRIORITIZATION", "Priority & Crew Recommendation Agent", NormalizeRecommendation(recRaw!, run.ProblemId.Value));
                target.OriginalOutputData = recRaw!.ToJsonString(Json);
                target.PreviousRecommendationId = ev.WorkflowEventId;
                target.InputData = ReviewMetadataJson.Write(job.InputData, new RecommendationReviewMetadata {
                    SchemaVersion = ReviewMetadataJson.CurrentVersion, Origin = ReviewOrigins.AiGenerated,
                    Revision = target.Revision, JobId = job.Id,
                    ChainId = ReviewMetadataJson.Read<ReviewJobMetadata>(job.InputData)?.ChainId });
                run.CurrentRecommendationId = target.WorkflowEventId;
                ev.ValidatedRevision = null;
            }
            validation = await RecordValidationAsync(run, target, validation, request, id);
            var reviewedRecommendationId = target.WorkflowEventId;
            technicalFailure = error != null || recRaw == null || Text(validation["status"]) is "ERROR" or "NOT_RUN" ||
                job.Kind == "REGENERATE" && (Text(validation["status"]) == "INVALID" || !bindingMatches);
            if (technicalFailure && target != ev)
            {
                // Keep the failed candidate and its review for audit, but do not replace
                // the previous current recommendation on a technical failure.
                run.CurrentRecommendationId = ev.WorkflowEventId;
                ev.ValidatedRevision = null;
                ev.ValidationResult = Failure("Regeneration failed. Retry or explicitly revalidate the previous recommendation.").ToJsonString(Json);
                target = ev;
                SetReviewProgress(run, ev, "NEEDS_ATTENTION", "Regeneration failed; previous recommendation retained.", job);
            }
            // Step 3: When Agent 4 validation passes, update the Problem's priority/status.
            // This was previously done inline in PersistInitialAsync but now only happens
            // after the worker produces a real VALID result.
            if (Text(validation["status"]) == "VALID" && target.ValidatedRevision == target.Revision && run.ProblemId.HasValue)
            {
                var recOutput = Obj(target.OutputData);
                var problem = await db.Problems.SingleOrDefaultAsync(p => p.ProblemId == run.ProblemId.Value);
                if (problem != null)
                {
                    var priority = Text(recOutput["priority"]);
                    var score = recOutput["priorityScore"]?.GetValue<int>();
                    if (!string.IsNullOrEmpty(priority)) problem.Priority = priority;
                    if (score.HasValue) problem.PriorityScore = score;
                    if (problem.Status is "IDENTIFIED" or "AWAITING_ASSIGNMENT")
                        problem.Status = "AWAITING_ASSIGNMENT";
                    problem.UpdatedAt = DateTime.UtcNow;
                }
            }
            job.Status = technicalFailure ? "FAILED" : "COMPLETED";
            job.Error = technicalFailure ? error ?? string.Join("; ", (validation["issues"] as JsonArray ?? new()).Select(Text)) : null;
            job.ResultRecommendationId = reviewedRecommendationId;
            var state = Obj(run.StateData);
            state["priorityAnalysis"] = JsonNode.Parse(target.OutputData!);
            state["recommendations"] = new JsonArray(JsonNode.Parse(target.OutputData!));
            state["safetyValidation"] = Obj(target.ValidationResult);
            state["latestReview"] = Node(new { jobId = job.Id, recommendationId = target.WorkflowEventId, revision = target.Revision, job.Status });
            run.StateData = state.ToJsonString(Json);
            var metadata = ReviewMetadataJson.Read<ReviewJobMetadata>(job.InputData);
            // Retry the same durable job for transient transport/model/evidence errors.
            // Every failed review remains a separate event; claims have their own cap.
            if (technicalFailure && metadata != null && job.Attempts < 3 &&
                (retryTransport || error == null && job.Kind == "VALIDATE" && Text(validation["status"]) == "ERROR"))
            {
                var due = DateTimeOffset.UtcNow.AddSeconds(job.Attempts == 1 ? 10 : 30);
                job.Status = "QUEUED";
                job.InputData = ReviewMetadataJson.Write(job.InputData, metadata with {
                    NextAttemptAt = due, NextAttemptUnixSeconds = due.ToUnixTimeSeconds() });
                QueueProgress(run, target, job);
            }
            else if (!technicalFailure && bindingMatches && metadata != null)
            {
                successor = CreateSuccessor(job, target, validation, metadata, recRaw!);
                if (successor != null) QueueProgress(run, target, successor);
                else if (Text(validation["status"]) == "REVISION_REQUIRED" &&
                    Text(validation["suggestedAction"]) is "REGENERATE" or "RETRY_VALIDATION")
                    SetReviewProgress(run, target, "NEEDS_ATTENTION", "Automatic review limit reached. Coordinator action is required.", job);
            }
        }
        job.LeaseToken = null; job.LeaseUntil = null; job.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        // Release the parent's active-job unique-index slot before inserting its child,
        // while retaining both writes in the same transaction under the workflow lock.
        if (successor != null)
        {
            db.AiReviewJobs.Add(successor);
            await db.SaveChangesAsync();
        }
        await tx.CommitAsync();
    }
}
