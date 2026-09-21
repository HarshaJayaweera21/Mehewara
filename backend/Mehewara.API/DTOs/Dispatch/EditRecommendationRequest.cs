using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Dispatch;

public class EditRecommendationRequest
{
    [RegularExpression("^(LOW|MEDIUM|HIGH|CRITICAL)$", ErrorMessage = "Priority must be LOW, MEDIUM, HIGH, or CRITICAL.")]
    public string? Priority { get; set; }

    [Range(0, 100, ErrorMessage = "Priority score must be between 0 and 100.")]
    public int? PriorityScore { get; set; }

    public Guid? RecommendedCrewId { get; set; }

    [Required(ErrorMessage = "editReason is required.")]
    public string EditReason { get; set; } = string.Empty;
}
