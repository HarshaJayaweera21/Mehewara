namespace Mehewara.API.Models;

public class ApprovalHistory
{
    public Guid ApprovalId { get; set; }
    public Guid? WorkOrderId { get; set; }
    public Guid? RecommendationId { get; set; }
    public Guid DecidedBy { get; set; }
    public string Decision { get; set; } = string.Empty;
    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; }

    public WorkOrder? WorkOrder { get; set; }
    public WorkflowEvent? Recommendation { get; set; }
    public User DecidedByUser { get; set; } = null!;
}
