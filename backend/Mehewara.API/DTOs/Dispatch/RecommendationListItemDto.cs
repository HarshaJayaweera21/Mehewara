namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationListItemDto
{
    public int Revision { get; set; }
    public bool IsCurrent { get; set; }
    public bool CanApprove { get; set; }
    public Guid? PreviousRecommendationId { get; set; }
    public Mehewara.API.Models.AiReviewJob? LatestJob { get; set; }
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
