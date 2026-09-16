namespace Mehewara.API.Models;

public class ReportPhoto
{
    public Guid PhotoId { get; set; }

    public Guid ReportId { get; set; }

    public string PhotoUrl { get; set; } = string.Empty;

    public string? FileName { get; set; }

    public string? MimeType { get; set; }

    public DateTime UploadedAt { get; set; }

    // Navigation property
    public Report Report { get; set; } = null!;
}