using System.Text.Json.Serialization;
namespace Mehewara.API.Models;

public class AiReviewJob
{
    public Guid Id { get; set; }
    public Guid WorkflowRunId { get; set; }
    public Guid RecommendationId { get; set; }
    public int ExpectedRevision { get; set; }
    public Guid RequestId { get; set; }
    public Guid RequestedBy { get; set; }
    public string Kind { get; set; } = "REGENERATE";
    public string Reason { get; set; } = "";
    public string Status { get; set; } = "QUEUED";
    [JsonIgnore] public string? InputData { get; set; }
    public string? Error { get; set; }
    public Guid? ResultRecommendationId { get; set; }
    [JsonIgnore] public Guid? LeaseToken { get; set; }
    [JsonIgnore] public DateTime? LeaseUntil { get; set; }
    public int Attempts { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
