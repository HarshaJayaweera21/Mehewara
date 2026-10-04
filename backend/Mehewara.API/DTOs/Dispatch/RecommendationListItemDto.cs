namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationListItemDto
{
    public int Revision { get; set; }
    public bool IsCurrent { get; set; }
    public Guid? CurrentRecommendationId { get; set; }
    public bool CanApprove { get; set; }
    public string? Origin { get; set; }
    public Guid? EditedBy { get; set; }
    public DateTimeOffset? EditedAt { get; set; }
    public bool RequiresResponsibilityAcknowledgement { get; set; }
    public Guid? PreviousRecommendationId { get; set; }
    public ReviewJobDto? LatestJob { get; set; }
    public string ReviewBucket { get; set; } = "NEEDS_ATTENTION";
    public string ReviewProgress { get; set; } = "NEEDS_ATTENTION";
    public string? AttentionReason { get; set; }
    public List<string> AllowedActions { get; set; } = new();
    public Guid RecommendationId { get; set; }
    public Guid ProblemId { get; set; }
    public string ProblemTitle { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string Category { get; set; } = string.Empty;
    public string Priority { get; set; } = string.Empty;
    public int PriorityScore { get; set; }
    public List<string> PriorityReasons { get; set; } = new();
    public string RequiredCrewType { get; set; } = string.Empty;
    public Guid? RecommendedCrewId { get; set; }
    public string? RecommendedCrewName { get; set; }
    public string RecommendationReason { get; set; } = string.Empty;
    public int? EstimatedDurationMinutes { get; set; }
    public double? DistanceKm { get; set; }
    public int? EstimatedTravelMinutes { get; set; }
    public string DispatchStrategy { get; set; } = "STANDARD_DISPATCH";
    public RecommendationValidationDto Validation { get; set; } = new();
    public string? ReviewDecision { get; set; }
    public DateTime CreatedAt { get; set; }
}
