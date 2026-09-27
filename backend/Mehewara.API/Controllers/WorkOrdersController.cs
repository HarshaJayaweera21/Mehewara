using System.Security.Claims;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/work-orders")]
[Authorize]
public class WorkOrdersController : ControllerBase
{
    private readonly IWorkOrderService _orders;
    private readonly AppDbContext _context;
    private readonly ILogger<WorkOrdersController> _logger;

    public WorkOrdersController(
        IWorkOrderService orders,
        AppDbContext context,
        ILogger<WorkOrdersController> logger)
    {
        _orders = orders;
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> List([FromQuery] WorkOrderQuery query) => Ok(await _orders.GetAdminOrdersAsync(query));

    [HttpGet("{id:guid}")]
    [Authorize(Roles = CrewRoles.AllWithAdmin)]
    public async Task<IActionResult> Detail(Guid id) =>
        Ok(await _orders.GetOrderAsync(id, UserId(), User.IsInRole("ADMIN")));

    [HttpPost("{id:guid}/start")]
    [Authorize(Roles = CrewRoles.All)]
    public async Task<IActionResult> Start(Guid id) => Ok(await _orders.StartAsync(id, UserId()));

    [HttpPost("{id:guid}/complete")]
    [Authorize(Roles = CrewRoles.All)]
    public async Task<IActionResult> Complete(Guid id, [FromBody] CompleteWorkOrderRequest request) =>
        Ok(await _orders.CompleteAsync(id, UserId(), request));

    [HttpPost("{workOrderId:guid}/report-issue")]
    [Authorize(Roles = CrewRoles.AllWithAdmin)]
    [ProducesResponseType(typeof(CrewWorkOrderItemDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> ReportWorkOrderIssue(
        [FromRoute] Guid workOrderId,
        [FromBody] ReportWorkOrderIssueRequest request)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted);
        try
        {
            var workOrder = await _context.WorkOrders
                .FromSqlInterpolated($"SELECT * FROM work_orders WHERE work_order_id = {workOrderId} FOR UPDATE")
                .Include(w => w.Problem)
                .FirstOrDefaultAsync();

            if (workOrder == null)
            {
                throw new NotFoundException($"Work order '{workOrderId}' was not found.", "WORK_ORDER_NOT_FOUND");
            }

            await ValidateCrewAuthorizationAsync(workOrder.CrewId);

            if (workOrder.Status != "ASSIGNED" && workOrder.Status != "IN_PROGRESS")
            {
                throw new ConflictException(
                    $"Cannot report issue on work order with status '{workOrder.Status}'. Only active or queued work orders can be cancelled/flagged.",
                    "INVALID_STATUS_TRANSITION");
            }

            var crew = await _context.Crews
                .FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {workOrder.CrewId} FOR UPDATE")
                .FirstOrDefaultAsync();

            var isCancel = string.Equals(request.Action, "CANCEL", StringComparison.OrdinalIgnoreCase);
            var wasInProgress = workOrder.Status == "IN_PROGRESS";

            workOrder.Status = isCancel ? "CANCELLED" : "FAILED";
            workOrder.CompletedAt = DateTime.UtcNow;
            workOrder.CompletionNotes = $"[Issue Reported] {request.Reason.Trim()}";
            workOrder.UpdatedAt = DateTime.UtcNow;

            if (crew != null && wasInProgress)
            {
                crew.Status = "AVAILABLE";
                crew.UpdatedAt = DateTime.UtcNow;
            }

            var problem = await _context.Problems.FindAsync(workOrder.ProblemId);
            if (problem != null)
            {
                problem.Status = "AWAITING_ASSIGNMENT";
                problem.UpdatedAt = DateTime.UtcNow;
            }

            var linkedReports = await _context.Reports
                .Where(r => r.ProblemId == workOrder.ProblemId)
                .ToListAsync();

            foreach (var report in linkedReports)
            {
                if (report.Status != "RESOLVED")
                {
                    report.Status = "PENDING";
                    report.UpdatedAt = DateTime.UtcNow;
                }
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            _logger.LogInformation("Work order {WoId} closed with status {Status}. Reason: {Reason}. Problem {ProblemId} returned to AWAITING_ASSIGNMENT.",
                workOrderId, workOrder.Status, request.Reason, workOrder.ProblemId);

            return Ok(MapToDto(workOrder));
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    private async Task ValidateCrewAuthorizationAsync(Guid targetCrewId)
    {
        if (User.IsInRole("ADMIN"))
        {
            return;
        }

        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (string.IsNullOrWhiteSpace(userIdStr) || !Guid.TryParse(userIdStr, out var userId))
        {
            throw new UnauthorizedException("User identity could not be verified.", "UNAUTHORIZED");
        }

        var authorizedCrew = await _context.Crews
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.CrewLeaderUserId == userId);

        if (authorizedCrew == null || authorizedCrew.CrewId != targetCrewId)
        {
            throw new ForbiddenException("You are not authorized to update work orders for another squad.", "FORBIDDEN");
        }
    }

    private static CrewWorkOrderItemDto MapToDto(WorkOrder w)
    {
        return new CrewWorkOrderItemDto
        {
            Id = w.WorkOrderId,
            ProblemId = w.ProblemId,
            Title = w.Title,
            ProblemTitle = w.Problem?.Title ?? w.Title,
            ProblemDescription = w.Problem?.Description,
            ProblemCategory = w.Problem?.Category,
            ProblemAddress = w.Problem?.Address,
            Latitude = w.Problem?.Latitude ?? 0,
            Longitude = w.Problem?.Longitude ?? 0,
            ReportCount = w.Problem?.Reports?.Count ?? 0,
            Priority = w.Priority,
            PriorityScore = w.Problem?.PriorityScore ?? 0,
            Status = w.Status,
            Instructions = w.Instructions,
            AssignedAt = w.AssignedAt,
            StartedAt = w.StartedAt,
            CompletedAt = w.CompletedAt,
            CompletionNotes = w.CompletionNotes,
            CreatedAt = w.CreatedAt
        };
    }

    private Guid UserId() => Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
        ? id : throw new UnauthorizedException("User identifier claim is missing or invalid.");
}

[ApiController]
[Route("api/crew/work-orders")]
[Authorize(Roles = CrewRoles.All)]
public class CrewWorkOrdersController : ControllerBase
{
    private readonly IWorkOrderService _orders;
    public CrewWorkOrdersController(IWorkOrderService orders) => _orders = orders;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] WorkOrderQuery query)
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(claim, out var userId))
            throw new UnauthorizedException("User identifier claim is missing or invalid.");
        return Ok(await _orders.GetCrewOrdersAsync(query, userId));
    }
}

internal static class CrewRoles
{
    public const string All = "CREW_LEADER_DRAINAGE,CREW_LEADER_ROAD,CREW_LEADER_WASTE,CREW_LEADER_ELECTRICAL,CREW_LEADER_ENVIRONMENT";
    public const string AllWithAdmin = "ADMIN," + All;
}

