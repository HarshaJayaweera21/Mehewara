using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.WorkOrders;

public class WorkOrderQuery
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? Status { get; set; }
    public string? Priority { get; set; }
    public Guid? CrewId { get; set; }
    public Guid? ProblemId { get; set; }
    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
}

public class CompleteWorkOrderRequest
{
    [MaxLength(4000)]
    public string? CompletionNotes { get; set; }
}

public class WorkOrderDto
{
    public Guid Id { get; set; }
    public Guid ProblemId { get; set; }
    public Guid CrewId { get; set; }
    public Guid? RecommendationId { get; set; }
    public string CrewName { get; set; } = string.Empty;
    public string ProblemTitle { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Instructions { get; set; }
    public string Priority { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public string? Address { get; set; }
    public DateTime? AssignedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? CompletionNotes { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<WorkOrderActivityDto> History { get; set; } = new();
}

public class WorkOrderActivityDto
{
    public Guid Id { get; set; }
    public string Action { get; set; } = string.Empty;
    public Guid ActorUserId { get; set; }
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
}
