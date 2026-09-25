namespace Mehewara.API.DTOs.Problems.Consolidation;

public class LinkUncertainReportRequest
{
    public Guid ReportId { get; set; }
    public Guid ProblemId { get; set; }
    public string? CoordinatorNotes { get; set; }
}

public class CreateProblemFromUncertainReportRequest
{
    public Guid ReportId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string? CoordinatorNotes { get; set; }
}
