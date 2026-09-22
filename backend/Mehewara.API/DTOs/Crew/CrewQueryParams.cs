namespace Mehewara.API.DTOs.Crew;

public class CrewQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? CrewType { get; set; }
    public string? Status { get; set; }
    public string SortBy { get; set; } = "createdAt";
    public string SortDirection { get; set; } = "desc";
}
