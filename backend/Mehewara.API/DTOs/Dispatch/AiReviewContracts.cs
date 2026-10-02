using System.ComponentModel.DataAnnotations;
using System.Text.Json.Nodes;

namespace Mehewara.API.DTOs.Dispatch;

public class ReviewRequest
{
    [Range(1, int.MaxValue)] public int ExpectedRevision { get; set; }
    public Guid RequestId { get; set; }
    [Required, StringLength(4000, MinimumLength = 1)] public string Reason { get; set; } = "";
}

public class ValidationContextRequest
{
    public Guid WorkflowId { get; set; }
    public Guid? JobId { get; set; }
    public Guid? ProblemId { get; set; }
    public List<Guid> ReportIds { get; set; } = new();
    public Guid? CrewId { get; set; }
}

public record ReviewHistoryItem(Guid RecommendationId, Guid? PreviousRecommendationId,
    int Revision, DateTime CreatedAt, string? OutputData, string? ValidationResult, string? OriginalOutputData = null);

public record ValidationAttemptDto(Guid Id, DateTime StartedAt, DateTime? CompletedAt, string Status, string? Result);
public record RecommendationEditDto(Guid Id, DateTime CreatedAt, string? Reason, string Before, string After, Guid ActorUserId);

// Safe queue projection: execution context, credentials and lease tokens are not exposed.
public record ReviewJobDto(Guid Id, Guid WorkflowRunId, Guid RecommendationId, int ExpectedRevision, Guid RequestId, Guid RequestedBy,
    string Kind, string Status, string Reason, string? Error, Guid? ResultRecommendationId,
    DateTime CreatedAt, DateTime UpdatedAt, int Attempts, Guid? ChainId, Guid? ParentJobId,
    int? CorrectionCount, int? EvidenceRetryCount, DateTimeOffset? NextAttemptAt, string? Origin)
{
    public static ReviewJobDto From(Mehewara.API.Models.AiReviewJob job)
    {
        var metadata = ReviewMetadataJson.Read<ReviewJobMetadata>(job.InputData);
        return new(job.Id, job.WorkflowRunId, job.RecommendationId, job.ExpectedRevision, job.RequestId, job.RequestedBy, job.Kind, job.Status,
            job.Reason, job.Error, job.ResultRecommendationId, job.CreatedAt, job.UpdatedAt, job.Attempts,
            metadata?.ChainId, metadata?.ParentJobId, metadata?.CorrectionCount, metadata?.EvidenceRetryCount, metadata?.NextAttemptAt, metadata?.Origin);
    }
}
