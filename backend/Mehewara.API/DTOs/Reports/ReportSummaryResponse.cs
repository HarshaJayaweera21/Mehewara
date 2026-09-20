namespace Mehewara.API.DTOs.Reports;

public class ReportSummaryResponse
{
    public Guid Id { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public string Status { get; set; } = "PENDING";
    public int LinkedProblemCount { get; set; }
    public string? FirstPhotoUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}
