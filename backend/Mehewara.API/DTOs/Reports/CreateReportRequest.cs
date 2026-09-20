using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Reports;

public class CreateReportRequest
{
    [Required(ErrorMessage = "Description is required.")]
    [MinLength(10, ErrorMessage = "Description must be at least 10 characters long.")]
    [MaxLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
    public string Description { get; set; } = string.Empty;

    [Required(ErrorMessage = "Category is required.")]
    [MaxLength(50)]
    public string Category { get; set; } = string.Empty;

    [Required(ErrorMessage = "Latitude is required.")]
    [Range(-90.0, 90.0, ErrorMessage = "Latitude must be between -90 and 90 degrees.")]
    public decimal Latitude { get; set; }

    [Required(ErrorMessage = "Longitude is required.")]
    [Range(-180.0, 180.0, ErrorMessage = "Longitude must be between -180 and 180 degrees.")]
    public decimal Longitude { get; set; }

    [MaxLength(500)]
    public string? Address { get; set; }

    public List<ReportPhotoRequest>? Photos { get; set; }
}
