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
    int Revision, DateTime CreatedAt, string? OutputData, string? ValidationResult);

public record ValidationAttemptDto(Guid Id, DateTime StartedAt, DateTime? CompletedAt, string Status, string? Result);
public record RecommendationEditDto(Guid Id, DateTime CreatedAt, string? Reason, string Before, string After);
