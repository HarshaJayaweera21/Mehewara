using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Dispatch;

public class RejectRecommendationRequest
{
    [Required(ErrorMessage = "Reason is required for rejection.")]
    public string Reason { get; set; } = string.Empty;
}
