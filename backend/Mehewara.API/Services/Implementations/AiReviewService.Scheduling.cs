using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class AiReviewService
{
    private const int MaxAutomaticCorrections = 2;
    private const int MaxEvidenceRetries = 2;

    private async Task<bool> MarkRunningAsync(Guid id, Guid? token)
    {
        db.ChangeTracker.Clear();
        var identity = await db.AiReviewJobs.AsNoTracking().SingleAsync(j => j.Id == id);
        await using var tx = await db.Database.BeginTransactionAsync();
        var runId = identity.WorkflowRunId;
        // Match Finish/Enqueue lock order. Claim only holds a job lock in its own transaction.
        var run = await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        var job = await db.AiReviewJobs.FromSqlInterpolated($"SELECT * FROM ai_review_jobs WHERE id = {id} FOR UPDATE").SingleAsync();
        if (job.Status != "RUNNING" || job.LeaseToken != token || job.LeaseUntil == null || job.LeaseUntil <= DateTime.UtcNow)
            return false;
        var rec = await db.WorkflowEvents.SingleAsync(e => e.WorkflowEventId == job.RecommendationId);
        if (run.CurrentRecommendationId == rec.WorkflowEventId && rec.Revision == job.ExpectedRevision)
        {
            run.Status = "RUNNING";
            run.CurrentStage = job.Kind == "REGENERATE" ? "PRIORITIZATION" : "VALIDATION";
            SetReviewProgress(run, rec, "RUNNING", job: job);
        }
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return true;
    }

    private static void QueueProgress(WorkflowRun run, WorkflowEvent rec, AiReviewJob job)
    {
        rec.ValidatedRevision = null;
        run.Status = "RUNNING";
        run.CurrentStage = job.Kind == "REGENERATE" ? "PRIORITIZATION" : "VALIDATION";
        run.CompletedAt = null;
        SetReviewProgress(run, rec, "QUEUED", job: job);
    }

    private static AiReviewJob? CreateSuccessor(AiReviewJob parent, WorkflowEvent rec,
        JsonObject review, ReviewJobMetadata metadata, JsonObject reviewedRecommendation)
    {
        if (Text(review["status"]) != "REVISION_REQUIRED") return null;
        var action = Text(review["suggestedAction"]);
        var correct = action == "REGENERATE" && metadata.CorrectionCount < MaxAutomaticCorrections;
        var revalidate = action == "RETRY_VALIDATION" && metadata.EvidenceRetryCount < MaxEvidenceRetries;
        if (!correct && !revalidate) return null;
        var rejected = metadata.Feedback?.RejectedCrewIds.ToList() ?? new List<Guid>();
        rejected.AddRange((Obj(parent.InputData)["validationFeedback"]?["rejected_crew_ids"] as JsonArray ?? new())
            .Select(Id).Where(id => id.HasValue).Select(id => id!.Value));
        // Exclude only crews actually found unsuitable; unrelated findings must not
        // progressively blacklist an otherwise eligible roster.
        if ((review["checks"] as JsonArray ?? new()).Any(c =>
            c?["passed"] is JsonValue value && value.TryGetValue<bool>(out var passed) && !passed &&
            Text(c?["code"]) is "SPECIALTY" or "CREW_AVAILABLE" or "REJECTED_CREW") &&
            Id(reviewedRecommendation["recommendedCrewId"]) is Guid crewId)
            rejected.Add(crewId);
        var issues = (metadata.Feedback?.Issues ?? new List<string>())
            .Concat((review["issues"] as JsonArray ?? new()).Select(Text))
            .Where(s => !string.IsNullOrWhiteSpace(s)).Distinct().ToList();
        var corrections = (review["findings"] as JsonArray ?? new()).Select(f => Text(f?["correction"]))
            .Where(s => !string.IsNullOrWhiteSpace(s)).Distinct();
        var kind = correct ? "REGENERATE" : "VALIDATE";
        var due = DateTimeOffset.UtcNow.AddSeconds(revalidate ? 5 : 0);
        // One deterministic successor per completed attempt. The workflow lock and
        // lease gate make replay harmless; the existing request-ID constraint is retained.
        var requestId = new Guid(SHA256.HashData(Encoding.UTF8.GetBytes($"review-child:{parent.Id}:{kind}"))[..16]);
        var child = new AiReviewJob {
            Id = Guid.NewGuid(), WorkflowRunId = parent.WorkflowRunId,
            RecommendationId = rec.WorkflowEventId, ExpectedRevision = rec.Revision,
            RequestedBy = parent.RequestedBy, RequestId = requestId, Kind = kind,
            Reason = correct ? "Automatic correction requested by Agent 4." : "Automatic revalidation after evidence changed." };
        child.InputData = ReviewMetadataJson.Write(
            new JsonObject { ["previousValidation"] = review.DeepClone() }.ToJsonString(Json),
            metadata with {
                ParentJobId = parent.Id,
                CorrectionCount = metadata.CorrectionCount + (correct ? 1 : 0),
                EvidenceRetryCount = metadata.EvidenceRetryCount + (revalidate ? 1 : 0),
                NextAttemptAt = due, NextAttemptUnixSeconds = due.ToUnixTimeSeconds(),
                Feedback = new ReviewFeedbackMetadata {
                    Status = "REVISION_REQUIRED", Issues = issues,
                    RejectedCrewIds = rejected.Distinct().ToList(),
                    SuggestedAction = string.Join("\n", corrections),
                    CoordinatorReason = metadata.Feedback?.CoordinatorReason } });
        return child;
    }
}
