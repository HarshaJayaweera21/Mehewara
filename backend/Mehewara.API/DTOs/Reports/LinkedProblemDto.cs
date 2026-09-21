namespace Mehewara.API.DTOs.Reports;

public class LinkedProblemDto
{
    public Guid ProblemId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string? Priority { get; set; }
    public string WorkStatus { get; set; } = string.Empty;
    public DateTime LinkedAt { get; set; }
}
