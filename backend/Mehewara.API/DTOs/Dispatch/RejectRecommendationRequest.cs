using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Dispatch;

public class RejectRecommendationRequest
{
    [Range(1, int.MaxValue)] public int ExpectedRevision { get; set; }

    [Required(ErrorMessage = "Reason is required for rejection.")]
    public string Reason { get; set; } = string.Empty;
}
