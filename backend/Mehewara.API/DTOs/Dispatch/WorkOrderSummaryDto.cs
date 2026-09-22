namespace Mehewara.API.DTOs.Dispatch;

public class WorkOrderSummaryDto
{
    public Guid Id { get; set; }
    public Guid ProblemId { get; set; }
    public Guid CrewId { get; set; }
    public string Priority { get; set; } = string.Empty;
    public string Status { get; set; } = "ASSIGNED";
    public DateTime? AssignedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
