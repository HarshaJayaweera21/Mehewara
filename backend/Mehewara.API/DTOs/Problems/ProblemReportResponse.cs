namespace Mehewara.API.DTOs.Problems;

public class ProblemReportResponse
{
    public Guid Id { get; set; }

    public Guid ResidentId { get; set; }

    public string ResidentName { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public string? Address { get; set; }

    public string Status { get; set; } = string.Empty;

    public List<string> PhotoUrls { get; set; } = new();

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }
}
