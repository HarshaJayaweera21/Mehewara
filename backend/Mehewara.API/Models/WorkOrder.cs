namespace Mehewara.API.Models;

public class WorkOrder
{
    public Guid WorkOrderId { get; set; }
    public Guid ProblemId { get; set; }
    public Guid CrewId { get; set; }
    public string Priority { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Instructions { get; set; }
    public string Status { get; set; } = "PENDING_APPROVAL";
    public DateTime? AssignedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? CompletionNotes { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public Problem Problem { get; set; } = null!;
    public Crew Crew { get; set; } = null!;
    public ICollection<ApprovalHistory> ApprovalHistories { get; set; }
        = new List<ApprovalHistory>();
}