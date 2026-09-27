using System.Text.Json;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class WorkOrderService : IWorkOrderService
{
    private readonly AppDbContext _db;

    public WorkOrderService(AppDbContext db) => _db = db;

    public Task<PagedResult<WorkOrderDto>> GetAdminOrdersAsync(WorkOrderQuery query) => ListAsync(query, null);

    public async Task<PagedResult<WorkOrderDto>> GetCrewOrdersAsync(WorkOrderQuery query, Guid userId)
    {
        var crewId = await GetCrewIdAsync(userId);
        return await ListAsync(query, crewId);
    }

    private async Task<PagedResult<WorkOrderDto>> ListAsync(WorkOrderQuery query, Guid? ownedCrewId)
    {
        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        var orders = _db.WorkOrders.AsNoTracking().Include(w => w.Crew).Include(w => w.Problem).AsQueryable();
        if (ownedCrewId.HasValue) orders = orders.Where(w => w.CrewId == ownedCrewId.Value);
        else if (query.CrewId.HasValue) orders = orders.Where(w => w.CrewId == query.CrewId.Value);
        if (query.ProblemId.HasValue) orders = orders.Where(w => w.ProblemId == query.ProblemId.Value);
        if (!string.IsNullOrWhiteSpace(query.Status)) orders = orders.Where(w => w.Status == query.Status.Trim().ToUpper());
        if (!string.IsNullOrWhiteSpace(query.Priority)) orders = orders.Where(w => w.Priority == query.Priority.Trim().ToUpper());
        if (query.From.HasValue) orders = orders.Where(w => w.CreatedAt >= query.From.Value);
        if (query.To.HasValue) orders = orders.Where(w => w.CreatedAt <= query.To.Value);

        var total = await orders.CountAsync();
        var rows = await orders.OrderByDescending(w => w.CreatedAt).ThenByDescending(w => w.WorkOrderId)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return new PagedResult<WorkOrderDto>
        {
            Items = rows.Select(w => Map(w)).ToList(), Page = page, PageSize = pageSize,
            TotalItems = total, SortBy = "createdAt", SortDirection = "desc"
        };
    }

    public async Task<WorkOrderDto> GetOrderAsync(Guid id, Guid userId, bool isAdmin)
    {
        Guid? crewId = isAdmin ? null : await GetCrewIdAsync(userId);
        var order = await _db.WorkOrders.AsNoTracking().Include(w => w.Crew).Include(w => w.Problem)
            .FirstOrDefaultAsync(w => w.WorkOrderId == id);
        if (order == null) throw new NotFoundException("Work order not found.", "WORK_ORDER_NOT_FOUND");
        if (crewId.HasValue && order.CrewId != crewId.Value)
            throw new ForbiddenException("This work order belongs to another crew.", "WORK_ORDER_NOT_OWNED");
        var result = Map(order);
        result.History = await _db.ActivityHistories.AsNoTracking().Where(a => a.WorkOrderId == id)
            .OrderBy(a => a.CreatedAt).ThenBy(a => a.ActivityId)
            .Select(a => new WorkOrderActivityDto
            {
                Id = a.ActivityId, Action = a.Action, ActorUserId = a.ActorUserId,
                Note = a.Note, CreatedAt = a.CreatedAt
            }).ToListAsync();
        return result;
    }

    public Task<WorkOrderDto> StartAsync(Guid id, Guid userId) => TransitionAsync(id, userId, false, null);

    public Task<WorkOrderDto> CompleteAsync(Guid id, Guid userId, CompleteWorkOrderRequest request) =>
        TransitionAsync(id, userId, true, request.CompletionNotes);

    private async Task<WorkOrderDto> TransitionAsync(Guid id, Guid userId, bool complete, string? notes)
    {
        var ownedCrewId = await GetCrewIdAsync(userId);
        await using var transaction = await _db.Database.BeginTransactionAsync();
        var target = await _db.WorkOrders.AsNoTracking().Where(w => w.WorkOrderId == id)
            .Select(w => new { w.ProblemId, w.CrewId }).FirstOrDefaultAsync();
        if (target == null) throw new NotFoundException("Work order not found.", "WORK_ORDER_NOT_FOUND");
        if (target.CrewId != ownedCrewId)
            throw new ForbiddenException("This work order belongs to another crew.", "WORK_ORDER_NOT_OWNED");

        // Use the same Problem -> Crew lock order as dispatch approval.
        await _db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM problems WHERE problem_id = {target.ProblemId} FOR UPDATE");
        await _db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM crews WHERE crew_id = {target.CrewId} FOR UPDATE");
        await _db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM work_orders WHERE work_order_id = {id} FOR UPDATE");

        var order = await _db.WorkOrders.Include(w => w.Problem).Include(w => w.Crew)
            .FirstAsync(w => w.WorkOrderId == id);
        var expected = complete ? "IN_PROGRESS" : "ASSIGNED";
        if (order.Status != expected)
            throw new ConflictException($"Work order is {order.Status}; expected {expected}. Refresh and try again.", "WORK_ORDER_STATE_CONFLICT");

        var before = JsonSerializer.Serialize(new { order.Status, order.StartedAt, order.CompletedAt, order.CompletionNotes });
        var now = DateTime.UtcNow;
        order.Status = complete ? "COMPLETED" : "IN_PROGRESS";
        order.UpdatedAt = now;
        if (complete)
        {
            order.CompletedAt = now;
            order.CompletionNotes = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
            var otherProblemWork = await _db.WorkOrders.AnyAsync(w => w.WorkOrderId != id &&
                w.ProblemId == order.ProblemId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"));
            if (!otherProblemWork)
            {
                order.Problem.Status = "RESOLVED";
                order.Problem.UpdatedAt = now;
                var reports = await _db.Reports.Where(r => r.ProblemId == order.ProblemId && r.Status != "CANCELLED").ToListAsync();
                foreach (var report in reports) { report.Status = "RESOLVED"; report.UpdatedAt = now; }
            }
            var otherCrewWork = await _db.WorkOrders.AnyAsync(w => w.WorkOrderId != id &&
                w.CrewId == order.CrewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"));
            if (!otherCrewWork && order.Crew.Status != "UNAVAILABLE")
            {
                order.Crew.Status = "AVAILABLE";
                order.Crew.UpdatedAt = now;
            }
            if (order.RecommendationId.HasValue)
            {
                var run = await _db.WorkflowEvents.Where(e => e.WorkflowEventId == order.RecommendationId.Value)
                    .Select(e => e.WorkflowRun).FirstOrDefaultAsync();
                if (run != null)
                {
                    run.CurrentStage = "COMPLETED";
                    run.Status = "COMPLETED";
                    run.CompletedAt = now;
                    run.UpdatedAt = now;
                }
            }
        }
        else
        {
            order.StartedAt = now;
            order.Problem.Status = "IN_PROGRESS";
            order.Problem.UpdatedAt = now;
        }

        _db.ActivityHistories.Add(new ActivityHistory
        {
            ActivityId = Guid.NewGuid(), ActorUserId = userId,
            Action = complete ? "WORK_ORDER_COMPLETED" : "WORK_ORDER_STARTED",
            WorkOrderId = id, BeforeData = before,
            AfterData = JsonSerializer.Serialize(new { order.Status, order.StartedAt, order.CompletedAt, order.CompletionNotes }),
            Note = complete ? order.CompletionNotes : null, CreatedAt = now
        });
        await _db.SaveChangesAsync();
        await transaction.CommitAsync();
        return await GetOrderAsync(id, userId, false);
    }

    private async Task<Guid> GetCrewIdAsync(Guid userId)
    {
        var crewId = await _db.Crews.AsNoTracking().Where(c => c.CrewLeaderUserId == userId)
            .Select(c => (Guid?)c.CrewId).FirstOrDefaultAsync();
        return crewId ?? throw new ForbiddenException("No crew is linked to this leader account.", "CREW_NOT_LINKED");
    }

    private static WorkOrderDto Map(WorkOrder w) => new()
    {
        Id = w.WorkOrderId, ProblemId = w.ProblemId, CrewId = w.CrewId,
        RecommendationId = w.RecommendationId, CrewName = w.Crew.CrewName,
        ProblemTitle = w.Problem.Title, Title = w.Title, Instructions = w.Instructions,
        Priority = w.Priority, Status = w.Status, Latitude = w.Problem.Latitude,
        Longitude = w.Problem.Longitude, Address = w.Problem.Address,
        AssignedAt = w.AssignedAt, StartedAt = w.StartedAt, CompletedAt = w.CompletedAt,
        CompletionNotes = w.CompletionNotes, CreatedAt = w.CreatedAt, UpdatedAt = w.UpdatedAt
    };
}
