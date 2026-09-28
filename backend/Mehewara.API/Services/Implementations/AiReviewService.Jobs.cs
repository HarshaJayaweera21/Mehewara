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
        job.InputData = new JsonObject { ["previousValidation"] = Obj(ev.ValidationResult) }.ToJsonString(Json);
        db.AiReviewJobs.Add(job);
        ev.ValidatedRevision = null;
        ev.ValidationResult = Failure("AI review is queued.", "NOT_RUN").ToJsonString(Json);
        ev.WorkflowRun.Status = "RUNNING";
        ev.WorkflowRun.CurrentStage = kind == "REGENERATE" ? "PRIORITIZATION" : "VALIDATION";
        ev.WorkflowRun.CompletedAt = null;
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return job;
    }

    public async Task<AiReviewJob?> GetJobAsync(Guid id) => await db.AiReviewJobs.AsNoTracking().SingleOrDefaultAsync(j => j.Id == id);

    public async Task<AiReviewJob?> ClaimAsync(CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var now = DateTime.UtcNow;
        var candidates = await db.AiReviewJobs.FromSqlInterpolated($"SELECT * FROM ai_review_jobs WHERE status = 'QUEUED' OR (status = 'RUNNING' AND lease_until < {now}) ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED").ToListAsync(ct);
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
        var original = Obj(ev.WorkflowRun.InputData)["report"];
        if (original == null) throw new BadRequestException("Original report snapshot is missing; restart report analysis.");
        if (Text(original["description"]) != source.Description || Text(original["category"]) != source.Category ||
            original["latitude"]?.GetValue<decimal>() != source.Latitude || original["longitude"]?.GetValue<decimal>() != source.Longitude ||
            Text(original["address"]) != (source.Address ?? ""))
            throw new BadRequestException("Source report evidence changed; rerun report analysis before recommendation review.");
        var related = await db.Reports.AsNoTracking().Where(r => r.ProblemId == pid && r.Status != "CANCELLED")
            .OrderBy(r => r.ReportId).Take(101).Select(r => new { reportId = r.ReportId, r.ProblemId, r.Description,
                r.Category, r.Latitude, r.Longitude, r.Address, r.Status, r.CreatedAt }).ToListAsync();
        if (related.Count > 100) throw new BadRequestException("Problem has more than 100 reports; review requires a larger evidence policy.");
        var crews = await db.Crews.AsNoTracking().Select(c => new { crewId = c.CrewId, name = c.CrewName, c.CrewType, c.Status,
            activeWorkOrderId = c.WorkOrders.Where(w => w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS")
                .OrderBy(w => w.WorkOrderId).Select(w => (Guid?)w.WorkOrderId).FirstOrDefault() }).ToListAsync();
        var consolidation = Obj(problemAnalysis);
        // Initial CREATE_NEW now refers to its established real Problem; original output remains immutable.
        consolidation["decision"] = "LINK_EXISTING"; consolidation["problemId"] = pid.ToString(); consolidation["newProblem"] = null;
        consolidation["relatedReportIds"] = Node(related.Select(r => r.reportId));
        consolidation["updatedProblemDescription"] = problem.Description;
        return new JsonObject {
            ["workflowId"] = job.WorkflowRunId.ToString(), ["jobId"] = job.Id.ToString(), ["kind"] = job.Kind,
            ["report"] = original.DeepClone(), ["reportAnalysis"] = JsonNode.Parse(reportAnalysis),
            ["problemAnalysis"] = consolidation, ["priorityAnalysis"] = JsonNode.Parse(ev.OutputData!),
            ["previousValidation"] = Obj(job.InputData)["previousValidation"]?.DeepClone(),
            ["coordinatorFeedback"] = job.Reason + "\nPrevious findings: " + Text(Obj(job.InputData)["previousValidation"]?["issues"]),
            ["context"] = new JsonObject {
                ["candidateProblems"] = Node(new[] { new { problemId = pid, problem.Title, problem.Description, problem.Category,
                    problem.Latitude, problem.Longitude, problem.Address, problem.Status, reportCount = related.Count } }),
                ["relatedReports"] = Node(related), ["availableCrews"] = Node(crews) }
        };
    }

    public async Task ExecuteAsync(AiReviewJob claimed, CancellationToken stopping)
    {
        if (claimed.Status != "RUNNING") return;
        var token = claimed.LeaseToken;
        if (claimed.Error != null) { await FinishAsync(claimed.Id, token, null, claimed.Error); return; }
        try
        {
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
            await FinishAsync(claimed.Id, token, null, message);
        }
    }

    private async Task FinishAsync(Guid id, Guid? token, JsonObject? result, string? error)
    {
        db.ChangeTracker.Clear();
        var identity = await db.AiReviewJobs.AsNoTracking().SingleAsync(j => j.Id == id);
        await using var tx = await db.Database.BeginTransactionAsync();
        var runId = identity.WorkflowRunId;
        var run = await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        var job = await db.AiReviewJobs.FromSqlInterpolated($"SELECT * FROM ai_review_jobs WHERE id = {id} FOR UPDATE").SingleAsync();
        if (job.LeaseToken != token || job.Status != "RUNNING") return;
        var ev = await db.WorkflowEvents.SingleAsync(e => e.WorkflowEventId == job.RecommendationId);
        if (ev.Revision != job.ExpectedRevision || run.CurrentRecommendationId != ev.WorkflowEventId)
        {
            job.Status = "FAILED"; job.Error = "Result discarded because its recommendation changed.";
        }
        else
        {
            var validation = result?["safetyValidation"] as JsonObject ?? Failure(error ?? "Missing Agent 4 response.");
            var input = Obj(job.InputData);
            var recRaw = result?["priorityAnalysis"] as JsonObject;
            var request = new ValidationContextRequest { WorkflowId = runId, JobId = id, ProblemId = run.ProblemId,
                CrewId = Id(recRaw?["recommendedCrewId"] ?? Obj(ev.OutputData)["recommendedCrewId"]),
                ReportIds = (input["problemAnalysis"]?["relatedReportIds"] as JsonArray ?? new()).Select(Id).Where(x => x.HasValue).Select(x => x!.Value).ToList() };
            if (request.ProblemId.HasValue)
                await db.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {request.ProblemId.Value} FOR UPDATE").ToListAsync();
            if (request.CrewId.HasValue)
                await db.Crews.FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {request.CrewId.Value} FOR UPDATE").ToListAsync();
            var evidenceIds = request.ReportIds.Append(run.ReportId).Distinct().ToArray();
            await db.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE report_id = ANY({evidenceIds}) ORDER BY report_id FOR UPDATE").ToListAsync();
            if (Text(validation["status"]) == "VALID")
            {
                var fresh = await GetEvidenceAsync(request);
                if (Text(fresh["evidenceHash"]) != Text(validation["evidenceHash"]))
                    validation = Failure("Evidence changed during review; revalidate.", "REVISION_REQUIRED");
            }
            var technicalFailure = error != null || recRaw == null || Text(validation["status"]) is "ERROR" or "NOT_RUN";
            var target = ev;
            if (job.Kind == "REGENERATE" && !technicalFailure && run.ProblemId.HasValue)
            {
                target = Record(run, "PRIORITIZATION", "Priority & Crew Recommendation Agent", NormalizeRecommendation(recRaw!, run.ProblemId.Value));
                target.OriginalOutputData = recRaw!.ToJsonString(Json);
                target.PreviousRecommendationId = ev.WorkflowEventId;
                target.InputData = job.InputData;
                run.CurrentRecommendationId = target.WorkflowEventId;
                ev.ValidatedRevision = null;
            }
            await RecordValidationAsync(run, target, validation, request, id);
            job.Status = technicalFailure ? "FAILED" : "COMPLETED";
            job.Error = technicalFailure ? error ?? string.Join("; ", (validation["issues"] as JsonArray ?? new()).Select(Text)) : null;
            job.ResultRecommendationId = target.WorkflowEventId;
            var state = Obj(run.StateData);
            state["priorityAnalysis"] = JsonNode.Parse(target.OutputData!);
            state["recommendations"] = new JsonArray(JsonNode.Parse(target.OutputData!));
            state["safetyValidation"] = validation.DeepClone();
            state["latestReview"] = Node(new { jobId = job.Id, recommendationId = target.WorkflowEventId, revision = target.Revision, job.Status });
            run.StateData = state.ToJsonString(Json);
        }
        job.LeaseToken = null; job.LeaseUntil = null; job.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        await tx.CommitAsync();
    }
}
