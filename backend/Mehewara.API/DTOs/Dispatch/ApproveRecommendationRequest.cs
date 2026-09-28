namespace Mehewara.API.DTOs.Dispatch;

public class ApproveRecommendationRequest
{
    [System.ComponentModel.DataAnnotations.Range(1, int.MaxValue)] public int ExpectedRevision { get; set; }
    public string? Reason { get; set; }
    public string? Instructions { get; set; }
}
