namespace Mehewara.API.DTOs.Dispatch;

public class RejectRecommendationResponseDto
{
    public Guid RecommendationId { get; set; }
    public string Decision { get; set; } = "REJECTED";
    public string Reason { get; set; } = string.Empty;
    public Guid DecidedBy { get; set; }
    public DateTime DecidedAt { get; set; }
}
