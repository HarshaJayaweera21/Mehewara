namespace Mehewara.API.DTOs.Problems.Consolidation;

public class NearbyCandidateProblemSummary
{
    public Guid ProblemId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string? Address { get; set; }
    public double DistanceMeters { get; set; }
    public int ReportCount { get; set; }
}

public class UncertainReportResponse
{
    public Guid ReportId { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string ResidentName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public List<string> PhotoUrls { get; set; } = new();
    public string? AiUncertaintyReason { get; set; }
    public List<string> AiEvidence { get; set; } = new();
    public List<NearbyCandidateProblemSummary> NearbyCandidates { get; set; } = new();
}
