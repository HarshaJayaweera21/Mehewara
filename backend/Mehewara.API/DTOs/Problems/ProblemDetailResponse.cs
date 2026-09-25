namespace Mehewara.API.DTOs.Problems;

public class ProblemDetailResponse
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string Category { get; set; } = string.Empty;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public string? Address { get; set; }

    public string? Priority { get; set; }

    public int? PriorityScore { get; set; }

    public string Status { get; set; } = string.Empty;

    public List<RelatedReportSummary> RelatedReports { get; set; } = new();

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }
}

public class RelatedReportSummary
{
    public Guid ReportId { get; set; }

    public string Description { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    public string? Address { get; set; }

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public DateTime CreatedAt { get; set; }
}
