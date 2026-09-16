namespace Mehewara.API.Models;

public class Problem
{
    public Guid ProblemId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string? Priority { get; set; }
    public int? PriorityScore { get; set; }
    public string Status { get; set; } = "IDENTIFIED";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    
    public ICollection<ReportProblem> ReportProblems { get; set; } = new List<ReportProblem>();
    public ICollection<WorkOrder> WorkOrders { get; set; } = new List<WorkOrder>();
    public ICollection<WorkflowRun> WorkflowRuns { get; set; } = new List<WorkflowRun>();
}