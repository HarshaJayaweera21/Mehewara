namespace Mehewara.API.Models;

public class WorkflowRun
{
    public Guid WorkflowRunId { get; set; }
    public Guid ReportId { get; set; }
    public Guid? ProblemId { get; set; }
    public string CurrentStage { get; set; } = string.Empty;
    public string Status { get; set; } = "RUNNING";
    public string? StateData { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public Report Report { get; set; } = null!;
    public Problem? Problem { get; set; }
    public ICollection<WorkflowEvent> WorkflowEvents { get; set; }
        = new List<WorkflowEvent>();
}