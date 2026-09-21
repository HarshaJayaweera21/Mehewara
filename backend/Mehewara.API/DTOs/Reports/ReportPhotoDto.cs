namespace Mehewara.API.DTOs.Reports;

public class ReportPhotoDto
{
    public Guid PhotoId { get; set; }
    public string PhotoUrl { get; set; } = string.Empty;
    public string? FileName { get; set; }
    public string? MimeType { get; set; }
    public DateTime UploadedAt { get; set; }
}
