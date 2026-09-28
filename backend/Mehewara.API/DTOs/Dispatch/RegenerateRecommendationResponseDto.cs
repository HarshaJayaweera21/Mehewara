namespace Mehewara.API.DTOs.Dispatch;

public class RegenerateRecommendationResponseDto
{
    public Guid JobId { get; set; }
    public string Status { get; set; } = "QUEUED";
    public string StatusUrl { get; set; } = "";
    public Guid PreviousRecommendationId { get; set; }
    public Guid WorkflowId { get; set; }
    public Guid RequestedBy { get; set; }
    public DateTime RequestedAt { get; set; }
}
