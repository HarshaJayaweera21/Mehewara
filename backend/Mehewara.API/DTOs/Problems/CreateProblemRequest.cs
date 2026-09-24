using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Problems;

public class CreateProblemRequest
{
    [Required(ErrorMessage = "Title is required.")]
    [MaxLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    [Required(ErrorMessage = "Category is required.")]
    [RegularExpression("^(DRAINAGE|ROAD|WASTE|ELECTRICAL|ENVIRONMENT)$",
        ErrorMessage = "Category must be one of: DRAINAGE, ROAD, WASTE, ELECTRICAL, ENVIRONMENT.")]
    public string Category { get; set; } = string.Empty;

    [Range(-90.0, 90.0, ErrorMessage = "Latitude must be between -90 and 90.")]
    public decimal Latitude { get; set; }

    [Range(-180.0, 180.0, ErrorMessage = "Longitude must be between -180 and 180.")]
    public decimal Longitude { get; set; }

    public string? Address { get; set; }
}