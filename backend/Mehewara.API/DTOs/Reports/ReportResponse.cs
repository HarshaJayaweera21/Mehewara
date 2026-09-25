namespace Mehewara.API.DTOs.Reports;

public class ReportResponse
{
    public Guid Id { get; set; }
    public Guid ResidentId { get; set; }
    public string? ResidentName { get; set; }
    public string? ResidentEmail { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string Status { get; set; } = "PENDING";
    public string? AiAnalysis { get; set; }
    public List<ReportPhotoDto> Photos { get; set; } = new();
    public List<LinkedProblemDto> LinkedProblems { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
