namespace Mehewara.API.Models;

public class ReportProblem
{
    public Guid ReportProblemId { get; set; }
    public Guid ReportId { get; set; }
    public Guid ProblemId { get; set; }
    public string LinkType { get; set; } = string.Empty;
    public DateTime LinkedAt { get; set; }

    // Navigation properties
    public Report Report { get; set; } = null!;
    public Problem Problem { get; set; } = null!;
}