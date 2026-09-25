namespace Mehewara.API.DTOs.Problems.Consolidation;

public class NewProblemCandidateDto
{
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
}
