using System.Security.Claims;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/work-orders")]
[Authorize(Roles = "ADMIN,CREW_LEADER_DRAINAGE,CREW_LEADER_ROAD,CREW_LEADER_WASTE,CREW_LEADER_ELECTRICAL,CREW_LEADER_ENVIRONMENT")]
public class WorkOrdersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<WorkOrdersController> _logger;

    public WorkOrdersController(AppDbContext context, ILogger<WorkOrdersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet("{workOrderId:guid}")]
    [ProducesResponseType(typeof(CrewWorkOrderItemDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetWorkOrderById([FromRoute] Guid workOrderId)
    {
        var workOrder = await _context.WorkOrders
            .Include(w => w.Problem)
                .ThenInclude(p => p!.Reports)
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.WorkOrderId == workOrderId);

        if (workOrder == null)
        {
            throw new NotFoundException($"Work order '{workOrderId}' was not found.", "WORK_ORDER_NOT_FOUND");
        }

        await ValidateCrewAuthorizationAsync(workOrder.CrewId);

        return Ok(MapToDto(workOrder));
    }

    [HttpPost("{workOrderId:guid}/start")]
    [ProducesResponseType(typeof(CrewWorkOrderItemDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> StartWorkOrder([FromRoute] Guid workOrderId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted);
        try
        {
            // Lock work order
            var workOrder = await _context.WorkOrders
                .FromSqlInterpolated($"SELECT * FROM work_orders WHERE work_order_id = {workOrderId} FOR UPDATE")
                .Include(w => w.Problem)
                .FirstOrDefaultAsync();

            if (workOrder == null)
            {
                throw new NotFoundException($"Work order '{workOrderId}' was not found.", "WORK_ORDER_NOT_FOUND");
            }

            await ValidateCrewAuthorizationAsync(workOrder.CrewId);

            if (workOrder.Status == "IN_PROGRESS")
            {
                return Ok(MapToDto(workOrder));
            }

            if (workOrder.Status != "ASSIGNED")
            {
                throw new ConflictException(
                    $"Cannot start work order with status '{workOrder.Status}'. Only ASSIGNED work orders can be started.",
                    "INVALID_STATUS_TRANSITION");
            }

            // Lock crew row to serialize concurrent execution starts
            var crew = await _context.Crews
                .FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {workOrder.CrewId} FOR UPDATE")
                .FirstOrDefaultAsync();

            if (crew == null)
            {
                throw new NotFoundException($"Assigned crew '{workOrder.CrewId}' was not found.", "CREW_NOT_FOUND");
            }

            // Enforce domain invariant: At most one work order in IN_PROGRESS per crew
            var hasActiveJob = await _context.WorkOrders
                .AnyAsync(w => w.CrewId == workOrder.CrewId && w.Status == "IN_PROGRESS" && w.WorkOrderId != workOrderId);

            if (hasActiveJob)
            {
                throw new ConflictException(
                    $"Squad '{crew.CrewName}' already has an active work order in progress. Complete or report an issue on the active mission before starting another task.",
                    "ACTIVE_WORK_ORDER_EXISTS");
            }

            // Transition WorkOrder to IN_PROGRESS
            workOrder.Status = "IN_PROGRESS";
            workOrder.StartedAt = DateTime.UtcNow;
            workOrder.UpdatedAt = DateTime.UtcNow;

            // Transition Crew to BUSY
            crew.Status = "BUSY";
            crew.UpdatedAt = DateTime.UtcNow;

            // Transition Problem to IN_PROGRESS
            var problem = await _context.Problems.FindAsync(workOrder.ProblemId);
            if (problem != null)
            {
                problem.Status = "IN_PROGRESS";
                problem.UpdatedAt = DateTime.UtcNow;
            }

            // Transition linked Reports to PROCESSING
            var linkedReports = await _context.Reports
                .Where(r => r.ProblemId == workOrder.ProblemId)
                .ToListAsync();

            foreach (var report in linkedReports)
            {
                if (report.Status != "RESOLVED" && report.Status != "CANCELLED")
                {
                    report.Status = "PROCESSING";
                    report.UpdatedAt = DateTime.UtcNow;
                }
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            _logger.LogInformation("Work order {WoId} started by Crew {CrewId}. Squad marked BUSY.",
                workOrderId, workOrder.CrewId);

            return Ok(MapToDto(workOrder));
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException pgEx && pgEx.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            await transaction.RollbackAsync();
            throw new ConflictException(
                "A concurrent request already started another active work order for this squad.",
                "ACTIVE_WORK_ORDER_EXISTS");
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpPost("{workOrderId:guid}/complete")]
    [ProducesResponseType(typeof(CrewWorkOrderItemDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CompleteWorkOrder(
        [FromRoute] Guid workOrderId,
        [FromBody] CompleteWorkOrderRequest request)
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

            if (workOrder.Status != "IN_PROGRESS")
            {
                throw new ConflictException(
                    $"Cannot complete work order with status '{workOrder.Status}'. Only IN_PROGRESS work orders can be completed.",
                    "INVALID_STATUS_TRANSITION");
            }

            var crew = await _context.Crews
                .FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {workOrder.CrewId} FOR UPDATE")
                .FirstOrDefaultAsync();

            // Transition WorkOrder to COMPLETED
            workOrder.Status = "COMPLETED";
            workOrder.CompletedAt = DateTime.UtcNow;
            workOrder.CompletionNotes = request.CompletionNotes.Trim();
            workOrder.UpdatedAt = DateTime.UtcNow;

            // Transition Crew to AVAILABLE (frees active slot for next queued task)
            if (crew != null)
            {
                crew.Status = "AVAILABLE";
                crew.UpdatedAt = DateTime.UtcNow;
            }

            // Transition Problem to RESOLVED
            var problem = await _context.Problems.FindAsync(workOrder.ProblemId);
            if (problem != null)
            {
                problem.Status = "RESOLVED";
                problem.UpdatedAt = DateTime.UtcNow;
            }

            // Transition linked Reports to RESOLVED
            var linkedReports = await _context.Reports
                .Where(r => r.ProblemId == workOrder.ProblemId)
                .ToListAsync();

            foreach (var report in linkedReports)
            {
                report.Status = "RESOLVED";
                report.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            _logger.LogInformation("Work order {WoId} marked COMPLETED. Problem {ProblemId} RESOLVED. Crew {CrewId} set AVAILABLE.",
                workOrderId, workOrder.ProblemId, workOrder.CrewId);

            return Ok(MapToDto(workOrder));
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpPost("{workOrderId:guid}/report-issue")]
    [ProducesResponseType(typeof(CrewWorkOrderItemDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
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

            // Mark WorkOrder FAILED or CANCELLED with audit notes
            workOrder.Status = isCancel ? "CANCELLED" : "FAILED";
            workOrder.CompletedAt = DateTime.UtcNow;
            workOrder.CompletionNotes = $"[Issue Reported] {request.Reason.Trim()}";
            workOrder.UpdatedAt = DateTime.UtcNow;

            // Free squad back to AVAILABLE so they can move to next jobs in queue
            if (crew != null && wasInProgress)
            {
                crew.Status = "AVAILABLE";
                crew.UpdatedAt = DateTime.UtcNow;
            }

            // Return Problem to AWAITING_ASSIGNMENT so coordinators can re-dispatch
            var problem = await _context.Problems.FindAsync(workOrder.ProblemId);
            if (problem != null)
            {
                problem.Status = "AWAITING_ASSIGNMENT";
                problem.UpdatedAt = DateTime.UtcNow;
            }

            // Revert linked reports to ASSIGNED or PENDING
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

        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
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
}
