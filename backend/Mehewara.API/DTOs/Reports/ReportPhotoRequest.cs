using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Reports;

public class ReportPhotoRequest
{
    [Required]
    [Url]
    public string PhotoUrl { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? FileName { get; set; }

    [MaxLength(100)]
    public string? MimeType { get; set; }
}
