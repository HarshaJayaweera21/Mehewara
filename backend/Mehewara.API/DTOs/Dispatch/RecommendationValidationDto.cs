namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationValidationDto
{
    public string Status { get; set; } = "VALID";
    public List<string> Issues { get; set; } = new();
}
