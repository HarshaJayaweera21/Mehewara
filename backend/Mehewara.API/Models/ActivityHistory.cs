namespace Mehewara.API.Models;

public class ActivityHistory
{
    public Guid ActivityId { get; set; }
    public Guid ActorUserId { get; set; }
    public required string Action { get; set; }
    public Guid? RecommendationId { get; set; }
    public Guid? WorkOrderId { get; set; }
    public required string BeforeData { get; set; }
    public required string AfterData { get; set; }
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }

    public User ActorUser { get; set; } = null!;
    public WorkflowEvent? Recommendation { get; set; }
    public WorkOrder? WorkOrder { get; set; }
}
