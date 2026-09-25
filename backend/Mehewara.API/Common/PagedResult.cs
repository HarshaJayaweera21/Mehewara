namespace Mehewara.API.Common;

public class PagedResult<T>
{
    public IEnumerable<T> Items { get; set; } = Enumerable.Empty<T>();
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalItems { get; set; }
    public int TotalPages { get; set; }
    public string SortBy { get; set; } = string.Empty;
    public string SortDirection { get; set; } = string.Empty;
}
