using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class DispatchService
{
    private async Task<ReviewJobDto?> LatestReviewJobAsync(Guid runId)
    {
        var job = await _context.AiReviewJobs.AsNoTracking().Where(j => j.WorkflowRunId == runId)
            .OrderByDescending(j => j.Status == "QUEUED" || j.Status == "RUNNING")
            .ThenByDescending(j => j.CreatedAt).ThenByDescending(j => j.Id).FirstOrDefaultAsync();
        return job == null ? null : ReviewJobDto.From(job);
    }

    private static void SetDisplayState(WorkflowEvent ev, RecommendationListItemDto item)
    {
        item.CurrentRecommendationId = ev.WorkflowRun.CurrentRecommendationId;
        var active = item.LatestJob?.Status is "QUEUED" or "RUNNING";
        item.ReviewBucket = item.ReviewDecision is "APPROVED" or "REJECTED" ? "DECIDED" :
            !item.IsCurrent ? "HISTORY" : active ? "PROCESSING" : item.CanApprove ? "READY" : "NEEDS_ATTENTION";
        var metadata = ReviewMetadataJson.Read<WorkflowReviewMetadata>(ev.WorkflowRun.StateData);
        item.ReviewProgress = item.ReviewBucket is "HISTORY" or "DECIDED" ? item.ReviewBucket : active ? item.LatestJob!.Status : item.ReviewBucket == "READY"
            ? (item.RequiresResponsibilityAcknowledgement ? "HUMAN_APPROVAL" : "VALIDATED") : item.ReviewBucket;
        item.AttentionReason = item.ReviewBucket == "NEEDS_ATTENTION"
            ? item.Validation.Status == "VALID" || item.RequiresResponsibilityAcknowledgement
                ? "Current backend approval checks do not pass. Check Problem/report links, crew availability and conflicting work."
                : metadata?.RecommendationId == item.RecommendationId && metadata.Revision == item.Revision
                    ? metadata.AttentionReason : string.Join("; ", item.Validation.Issues)
            : null;
        if (item.ReviewBucket == "NEEDS_ATTENTION" && item.LatestJob?.Kind == "REGENERATE" && item.LatestJob.Status == "FAILED")
            item.AttentionReason = "Regeneration failed; the previous recommendation is retained. Retry regeneration, or review the current revision before taking further action.";
        if (item.ReviewBucket == "NEEDS_ATTENTION" && string.IsNullOrWhiteSpace(item.AttentionReason))
            item.AttentionReason = "Review is incomplete. Inspect the findings and current recommendation before taking action.";
        if (!item.IsCurrent || item.ReviewBucket == "DECIDED" || active) return;
        item.AllowedActions.AddRange(new[] { "EDIT", "REGENERATE", "REJECT" });
        if (!item.RequiresResponsibilityAcknowledgement) item.AllowedActions.Add("VALIDATE");
        if (item.CanApprove) item.AllowedActions.Add("APPROVE");
    }
}
