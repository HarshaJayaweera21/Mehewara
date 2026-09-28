namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationValidationDto
{
    public string Status { get; set; } = "NOT_RUN";
    public List<System.Text.Json.Nodes.JsonObject> Checks { get; set; } = new();
    public List<System.Text.Json.Nodes.JsonObject> Findings { get; set; } = new();
    public string? PolicyVersion { get; set; }
    public string? SuggestedAction { get; set; }
    public string? SnapshotHash { get; set; }
    public string? SnapshotAt { get; set; }
    public List<string> EvidenceRefs { get; set; } = new();
    public List<string> Issues { get; set; } = new();
}
