namespace Mehewara.API.DTOs.Problems.Consolidation;

public class ProblemContextDto
{
    public Guid ProblemId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string Status { get; set; } = string.Empty;
    public List<Guid> RelatedReportIds { get; set; } = new();
    public int RelatedReportCount { get; set; }
    public List<string> ReportedImpacts { get; set; } = new();
    public List<string> Hazards { get; set; } = new();
    public string ConsolidationSummary { get; set; } = string.Empty;
}
