namespace Mehewara.API.Models;

public class Report
{
    public Guid ReportId { get; set; }

    public Guid ResidentId { get; set; }

    public string Description { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public string? Address { get; set; }

    public string Status { get; set; } = "PENDING";

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public User Resident { get; set; } = null!;

    public ICollection<ReportPhoto> Photos { get; set; } = new List<ReportPhoto>();

    public ICollection<ReportProblem> ReportProblems { get; set; } = new List<ReportProblem>();

    public ICollection<WorkflowRun> WorkflowRuns { get; set; } = new List<WorkflowRun>();
}