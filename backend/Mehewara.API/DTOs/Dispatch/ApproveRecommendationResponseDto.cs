namespace Mehewara.API.DTOs.Dispatch;

public class ApproveRecommendationResponseDto
{
    public Guid RecommendationId { get; set; }
    public string Decision { get; set; } = "APPROVED";
    public Guid DecidedBy { get; set; }
    public DateTime DecidedAt { get; set; }
    public WorkOrderSummaryDto WorkOrder { get; set; } = null!;
}
