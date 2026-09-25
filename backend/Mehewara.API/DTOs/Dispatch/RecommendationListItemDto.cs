namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationListItemDto
{
    public Guid RecommendationId { get; set; }
    public Guid ProblemId { get; set; }
    public string ProblemTitle { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Priority { get; set; } = string.Empty;
    public int PriorityScore { get; set; }
    public List<string> PriorityReasons { get; set; } = new();
    public string RequiredCrewType { get; set; } = string.Empty;
    public Guid? RecommendedCrewId { get; set; }
    public string? RecommendedCrewName { get; set; }
    public string RecommendationReason { get; set; } = string.Empty;
    public RecommendationValidationDto Validation { get; set; } = new();
    public string? ReviewDecision { get; set; }
    public DateTime CreatedAt { get; set; }
}
