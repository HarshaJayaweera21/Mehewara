namespace Mehewara.API.DTOs.Dispatch;

public class RecommendationQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public Guid? ProblemId { get; set; }
    public string? Priority { get; set; }
    public string? ReviewDecision { get; set; }
    public string SortBy { get; set; } = "createdAt";
    public string SortDirection { get; set; } = "desc";
}
