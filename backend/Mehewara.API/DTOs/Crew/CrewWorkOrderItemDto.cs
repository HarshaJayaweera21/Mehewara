namespace Mehewara.API.DTOs.Crew;

public class CrewWorkOrderItemDto
{
    public Guid Id { get; set; }
    public Guid ProblemId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string ProblemTitle { get; set; } = string.Empty;
    public string? ProblemDescription { get; set; }
    public string? ProblemCategory { get; set; }
    public string? ProblemAddress { get; set; }
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public int ReportCount { get; set; }
    public string Priority { get; set; } = string.Empty;
    public int PriorityScore { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Instructions { get; set; }
    public DateTime? AssignedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? CompletionNotes { get; set; }
    public DateTime CreatedAt { get; set; }
}

