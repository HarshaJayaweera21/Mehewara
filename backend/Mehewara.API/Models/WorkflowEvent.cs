namespace Mehewara.API.Models;

public class WorkflowEvent
{
    public Guid WorkflowEventId { get; set; }
    public Guid WorkflowRunId { get; set; }
    public string AgentName { get; set; } = string.Empty;
    public string Stage { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? InputData { get; set; }
    public int Revision { get; set; } = 1;
    public Guid? PreviousRecommendationId { get; set; }
    public string? OriginalOutputData { get; set; }
    public int? ValidatedRevision { get; set; }
    public string? EvidenceHash { get; set; }
    public string? EvidenceRequest { get; set; }
    public string? OutputData { get; set; }
    public string? ValidationResult { get; set; }
    public string? ToolResults { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    // Navigation property
    public WorkflowRun WorkflowRun { get; set; } = null!;
}