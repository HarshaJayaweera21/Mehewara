namespace Mehewara.API.DTOs.Dispatch;

public class Agent3RecommendationPayload
{
    public Guid ProblemId { get; set; }
    public string Priority { get; set; } = string.Empty;
    public int PriorityScore { get; set; }
    public List<string> PriorityReasons { get; set; } = new();
    public string RequiredCrewType { get; set; } = string.Empty;
    public Guid? RecommendedCrewId { get; set; }
    public string RecommendationReason { get; set; } = string.Empty;
}
