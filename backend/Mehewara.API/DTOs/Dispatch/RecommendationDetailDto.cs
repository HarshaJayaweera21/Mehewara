namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationDetailDto : RecommendationListItemDto
{
    public System.Text.Json.Nodes.JsonObject? HumanOverrideApproval { get; set; }
    public List<ValidationAttemptDto> ValidationHistory { get; set; } = new();
    public List<RecommendationEditDto> EditHistory { get; set; } = new();
    public List<ReviewHistoryItem> History { get; set; } = new();
    public string? ProblemDescription { get; set; }
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public int ReportCount { get; set; }
    public List<string> ReportDescriptions { get; set; } = new();
    public string? RecommendedCrewStatus { get; set; }
    public string? ReviewReason { get; set; }
    public Guid? ReviewedBy { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public Guid? WorkOrderId { get; set; }
}
