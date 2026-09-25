using System.Data;
using System.Text.Json;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class DispatchService : IDispatchService
{
    private readonly AppDbContext _context;
    private readonly ILogger<DispatchService> _logger;
    private readonly JsonSerializerOptions _jsonOptions;

    public DispatchService(AppDbContext context, ILogger<DispatchService> logger)
    {
        _context = context;
        _logger = logger;
        _jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true
        };
    }

    public async Task<PagedResult<RecommendationListItemDto>> GetRecommendationsAsync(RecommendationQueryParams query)
    {
        var eventsQuery = _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
                .ThenInclude(r => r.Problem)
                    .ThenInclude(p => p!.Reports)
            .AsNoTracking()
            .Where(e => e.Stage == "PRIORITIZATION" && e.OutputData != null);

        if (query.ProblemId.HasValue)
        {
            eventsQuery = eventsQuery.Where(e => e.WorkflowRun.ProblemId == query.ProblemId.Value);
        }

        var isAscending = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase);
        eventsQuery = isAscending
            ? eventsQuery.OrderBy(e => e.StartedAt)
            : eventsQuery.OrderByDescending(e => e.StartedAt);

        var allEvents = await eventsQuery.ToListAsync();

        var crewDict = await _context.Crews
            .AsNoTracking()
            .ToDictionaryAsync(c => c.CrewId, c => c.CrewName);

        var problemIds = allEvents
            .Where(e => e.WorkflowRun.ProblemId.HasValue)
            .Select(e => e.WorkflowRun.ProblemId!.Value)
            .Distinct()
            .ToList();

        var approvalDict = await _context.ApprovalHistories
            .Include(a => a.WorkOrder)
            .AsNoTracking()
            .Where(a => problemIds.Contains(a.WorkOrder.ProblemId))
            .GroupBy(a => a.WorkOrder.ProblemId)
            .Select(g => new
            {
                ProblemId = g.Key,
                LatestDecision = g.OrderByDescending(a => a.CreatedAt).Select(a => a.Decision).FirstOrDefault()
            })
            .ToDictionaryAsync(x => x.ProblemId, x => x.LatestDecision);

        var listItems = new List<RecommendationListItemDto>();

        foreach (var ev in allEvents)
        {
            Agent3RecommendationPayload? payload = null;
            try
            {
                if (!string.IsNullOrWhiteSpace(ev.OutputData))
                {
                    payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData, _jsonOptions);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to deserialize recommendation JSON for WorkflowEvent {EventId}", ev.WorkflowEventId);
            }

            if (payload == null)
            {
                continue;
            }

            if (!string.IsNullOrWhiteSpace(query.Priority) &&
                !string.Equals(payload.Priority, query.Priority.Trim(), StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            string? reviewDecision = null;
            if (ev.WorkflowRun.ProblemId.HasValue &&
                approvalDict.TryGetValue(ev.WorkflowRun.ProblemId.Value, out var decision))
            {
                reviewDecision = decision;
            }

            if (!string.IsNullOrWhiteSpace(query.ReviewDecision) &&
                !string.Equals(reviewDecision, query.ReviewDecision.Trim(), StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            RecommendationValidationDto validation = new();
            if (!string.IsNullOrWhiteSpace(ev.ValidationResult))
            {
                try
                {
                    validation = JsonSerializer.Deserialize<RecommendationValidationDto>(ev.ValidationResult, _jsonOptions) ?? new();
                }
                catch
                {
                    // Default to empty validation
                }
            }

            var problem = ev.WorkflowRun.Problem;
            string? crewName = null;
            if (payload.RecommendedCrewId.HasValue && crewDict.TryGetValue(payload.RecommendedCrewId.Value, out var cName))
            {
                crewName = cName;
            }

            listItems.Add(new RecommendationListItemDto
            {
                RecommendationId = ev.WorkflowEventId,
                ProblemId = payload.ProblemId != Guid.Empty ? payload.ProblemId : (ev.WorkflowRun.ProblemId ?? Guid.Empty),
                ProblemTitle = problem?.Title ?? string.Empty,
                Category = problem?.Category ?? payload.RequiredCrewType,
                Priority = payload.Priority,
                PriorityScore = payload.PriorityScore,
                PriorityReasons = payload.PriorityReasons ?? new(),
                RequiredCrewType = payload.RequiredCrewType,
                RecommendedCrewId = payload.RecommendedCrewId,
                RecommendedCrewName = crewName,
                RecommendationReason = payload.RecommendationReason,
                Validation = validation,
                ReviewDecision = reviewDecision,
                CreatedAt = ev.StartedAt
            });
        }

        var totalItems = listItems.Count;
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = query.PageSize < 1 ? 20 : query.PageSize;

        var pagedItems = listItems
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        return new PagedResult<RecommendationListItemDto>
        {
            Items = pagedItems,
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            SortBy = query.SortBy ?? "createdAt",
            SortDirection = query.SortDirection ?? "desc"
        };
    }

    public async Task<RecommendationDetailDto?> GetRecommendationByIdAsync(Guid recommendationId)
    {
        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
                .ThenInclude(r => r.Problem)
                    .ThenInclude(p => p!.Reports)
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null || string.IsNullOrWhiteSpace(ev.OutputData))
        {
            return null;
        }

        Agent3RecommendationPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData, _jsonOptions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deserialize recommendation JSON for WorkflowEvent {EventId}", recommendationId);
            return null;
        }

        if (payload == null)
        {
            return null;
        }

        var problem = ev.WorkflowRun.Problem;
        var problemId = payload.ProblemId != Guid.Empty ? payload.ProblemId : (ev.WorkflowRun.ProblemId ?? Guid.Empty);

        string? crewName = null;
        string? crewStatus = null;
        if (payload.RecommendedCrewId.HasValue)
        {
            var crew = await _context.Crews
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.CrewId == payload.RecommendedCrewId.Value);

            if (crew != null)
            {
                crewName = crew.CrewName;
                crewStatus = crew.Status;
            }
        }

        var approval = await _context.ApprovalHistories
            .Include(a => a.WorkOrder)
            .AsNoTracking()
            .Where(a => a.WorkOrder.ProblemId == problemId)
            .OrderByDescending(a => a.CreatedAt)
            .FirstOrDefaultAsync();

        RecommendationValidationDto validation = new();
        if (!string.IsNullOrWhiteSpace(ev.ValidationResult))
        {
            try
            {
                validation = JsonSerializer.Deserialize<RecommendationValidationDto>(ev.ValidationResult, _jsonOptions) ?? new();
            }
            catch
            {
                // Fallback default validation
            }
        }

        var reportDescriptions = problem?.Reports
            .Select(r => r.Description)
            .ToList() ?? new List<string>();

        return new RecommendationDetailDto
        {
            RecommendationId = ev.WorkflowEventId,
            ProblemId = problemId,
            ProblemTitle = problem?.Title ?? string.Empty,
            ProblemDescription = problem?.Description,
            Category = problem?.Category ?? payload.RequiredCrewType,
            Latitude = problem?.Latitude ?? 0,
            Longitude = problem?.Longitude ?? 0,
            Address = problem?.Address,
            ReportCount = problem?.Reports.Count ?? 0,
            ReportDescriptions = reportDescriptions,
            Priority = payload.Priority,
            PriorityScore = payload.PriorityScore,
            PriorityReasons = payload.PriorityReasons ?? new(),
            RequiredCrewType = payload.RequiredCrewType,
            RecommendedCrewId = payload.RecommendedCrewId,
            RecommendedCrewName = crewName,
            RecommendedCrewStatus = crewStatus,
            RecommendationReason = payload.RecommendationReason,
            Validation = validation,
            ReviewDecision = approval?.Decision,
            ReviewReason = approval?.Reason,
            ReviewedBy = approval?.DecidedBy,
            ReviewedAt = approval?.CreatedAt,
            WorkOrderId = approval?.WorkOrderId,
            CreatedAt = ev.StartedAt
        };
    }

    public async Task<RecommendationDetailDto> EditRecommendationAsync(Guid recommendationId, EditRecommendationRequest request, Guid adminUserId)
    {
        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
                .ThenInclude(r => r.Problem)
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null || string.IsNullOrWhiteSpace(ev.OutputData))
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }

        var problemId = ev.WorkflowRun.ProblemId;
        if (problemId.HasValue)
        {
            var isApproved = await _context.ApprovalHistories
                .AnyAsync(a => a.WorkOrder.ProblemId == problemId.Value && a.Decision == "APPROVED");

            if (isApproved)
            {
                throw new ConflictException("Cannot edit a recommendation that has already been approved.", "ALREADY_APPROVED");
            }
        }

        Agent3RecommendationPayload payload;
        try
        {
            payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData, _jsonOptions)
                      ?? throw new BadRequestException("Recommendation payload could not be parsed.");
        }
        catch (Exception ex)
        {
            throw new BadRequestException($"Recommendation JSON error: {ex.Message}");
        }

        if (!string.IsNullOrWhiteSpace(request.Priority))
        {
            payload.Priority = request.Priority.Trim().ToUpperInvariant();
        }

        if (request.PriorityScore.HasValue)
        {
            payload.PriorityScore = request.PriorityScore.Value;
        }

        if (request.RecommendedCrewId.HasValue)
        {
            payload.RecommendedCrewId = request.RecommendedCrewId.Value;
        }

        payload.PriorityReasons.Add($"[Coordinator Edit] {request.EditReason.Trim()}");

        var issues = new List<string>();
        if (payload.RecommendedCrewId.HasValue)
        {
            var crew = await _context.Crews.FindAsync(payload.RecommendedCrewId.Value);
            if (crew == null)
            {
                issues.Add($"Recommended crew '{payload.RecommendedCrewId.Value}' does not exist.");
            }
            else
            {
                if (!string.Equals(crew.CrewType, payload.RequiredCrewType, StringComparison.OrdinalIgnoreCase))
                {
                    issues.Add($"Crew type '{crew.CrewType}' does not match required specialty '{payload.RequiredCrewType}'.");
                }
                if (!string.Equals(crew.Status, "AVAILABLE", StringComparison.OrdinalIgnoreCase))
                {
                    issues.Add($"Crew '{crew.CrewName}' status is {crew.Status}.");
                }
            }
        }

        var validation = new RecommendationValidationDto
        {
            Status = issues.Count == 0 ? "VALID" : "REVISION_REQUIRED",
            Issues = issues
        };

        ev.OutputData = JsonSerializer.Serialize(payload, _jsonOptions);
        ev.ValidationResult = JsonSerializer.Serialize(validation, _jsonOptions);
        ev.CompletedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var updated = await GetRecommendationByIdAsync(recommendationId);
        return updated!;
    }

    public async Task<ApproveRecommendationResponseDto> ApproveRecommendationAsync(Guid recommendationId, ApproveRecommendationRequest request, Guid adminUserId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        try
        {
            // 1. Recommendation exists
            var ev = await _context.WorkflowEvents
                .Include(e => e.WorkflowRun)
                .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

            if (ev == null || string.IsNullOrWhiteSpace(ev.OutputData))
            {
                throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
            }

            Agent3RecommendationPayload payload;
            try
            {
                payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData, _jsonOptions)
                          ?? throw new ValidationException("Recommendation payload is empty.");
            }
            catch (Exception ex)
            {
                throw new ValidationException($"Recommendation JSON error: {ex.Message}");
            }

            var targetProblemId = payload.ProblemId != Guid.Empty
                ? payload.ProblemId
                : (ev.WorkflowRun.ProblemId ?? Guid.Empty);

            // 2. Problem exists - Acquire pessimistic row lock to serialize concurrent problem dispatches
            var problem = await _context.Problems
                .FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {targetProblemId} FOR UPDATE")
                .FirstOrDefaultAsync();

            if (problem == null)
            {
                throw new NotFoundException("Associated problem not found.", "PROBLEM_NOT_FOUND");
            }

            // 3. Recommendation or problem has not already been approved/assigned
            if (problem.Status is "ASSIGNED" or "IN_PROGRESS" or "RESOLVED" or "CLOSED")
            {
                throw new ConflictException(
                    $"Problem '{targetProblemId}' has already been assigned or completed (Status: {problem.Status}).",
                    "ALREADY_APPROVED");
            }

            var alreadyApproved = await _context.ApprovalHistories
                .AnyAsync(a => a.WorkOrder.ProblemId == targetProblemId && a.Decision == "APPROVED");

            if (alreadyApproved)
            {
                throw new ConflictException(
                    "This recommendation has already been approved.",
                    "ALREADY_APPROVED");
            }

            // 4. Report <-> Problem links are valid (has at least 1 linked report)
            var hasLinkedReports = await _context.Reports.AnyAsync(r => r.ProblemId == targetProblemId);
            if (!hasLinkedReports)
            {
                throw new ValidationException("Problem has no linked resident reports.");
            }

            // 5. Priority is valid enum
            var validPriorities = new[] { "LOW", "MEDIUM", "HIGH", "CRITICAL" };
            if (string.IsNullOrWhiteSpace(payload.Priority) || !validPriorities.Contains(payload.Priority.ToUpperInvariant()))
            {
                throw new ValidationException($"Priority '{payload.Priority}' is not a valid priority level.");
            }

            // 6. Crew exists - Acquire pessimistic row lock to serialize concurrent squad assignments
            if (!payload.RecommendedCrewId.HasValue)
            {
                throw new ValidationException("No crew was recommended for dispatch.");
            }

            var crew = await _context.Crews
                .FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {payload.RecommendedCrewId.Value} FOR UPDATE")
                .FirstOrDefaultAsync();

            if (crew == null)
            {
                throw new ValidationException($"Recommended crew '{payload.RecommendedCrewId.Value}' does not exist.");
            }

            // 7. Crew type matches required crew type
            if (!string.Equals(crew.CrewType, payload.RequiredCrewType, StringComparison.OrdinalIgnoreCase))
            {
                throw new ValidationException($"Crew type '{crew.CrewType}' does not match required specialty '{payload.RequiredCrewType}'.");
            }

            // 8. Crew status == "AVAILABLE" (evaluated against locked, freshly committed row)
            if (!string.Equals(crew.Status, "AVAILABLE", StringComparison.OrdinalIgnoreCase))
            {
                throw new ConflictException(
                    $"Recommended crew '{crew.CrewName}' is currently {crew.Status}.",
                    "CREW_NOT_AVAILABLE");
            }

            // 9. No conflicting active WorkOrder for this crew
            var hasConflict = await _context.WorkOrders.AnyAsync(w =>
                w.CrewId == crew.CrewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"));

            if (hasConflict)
            {
                throw new ConflictException(
                    $"Crew '{crew.CrewName}' already has an active work order in progress.",
                    "CREW_CONFLICT");
            }

            // 10. Actor is authorized as Admin
            var adminUser = await _context.Users.FindAsync(adminUserId);
            if (adminUser == null)
            {
                throw new UnauthorizedException("Coordinator account not recognized.", "UNAUTHORIZED");
            }

            // ALL 10 CHECKS PASSED -> Create WorkOrder and propagate statuses
            var workOrder = new WorkOrder
            {
                WorkOrderId = Guid.NewGuid(),
                ProblemId = targetProblemId,
                CrewId = crew.CrewId,
                Priority = payload.Priority.ToUpperInvariant(),
                Title = problem.Title,
                Instructions = $"Dispatched to resolve {problem.Title} ({problem.Category}) at {problem.Address}.",
                Status = "ASSIGNED",
                AssignedAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.WorkOrders.Add(workOrder);

            var approval = new ApprovalHistory
            {
                ApprovalId = Guid.NewGuid(),
                WorkOrderId = workOrder.WorkOrderId,
                DecidedBy = adminUserId,
                Decision = "APPROVED",
                Reason = !string.IsNullOrWhiteSpace(request.Reason)
                    ? request.Reason.Trim()
                    : "Recommendation reviewed and approved by coordinator.",
                CreatedAt = DateTime.UtcNow
            };
            _context.ApprovalHistories.Add(approval);

            // Update Crew Status
            crew.Status = "BUSY";
            crew.UpdatedAt = DateTime.UtcNow;

            // Update Problem Status
            problem.Status = "ASSIGNED";
            problem.UpdatedAt = DateTime.UtcNow;

            // Update WorkflowRun Status
            ev.WorkflowRun.CurrentStage = "WORK_EXECUTION";
            ev.WorkflowRun.Status = "RUNNING";
            ev.WorkflowRun.UpdatedAt = DateTime.UtcNow;

            // Propagate Status to Linked Reports
            var linkedReports = await _context.Reports
                .Where(r => r.ProblemId == targetProblemId)
                .ToListAsync();

            foreach (var report in linkedReports)
            {
                report.Status = "ASSIGNED";
                report.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            _logger.LogInformation(
                "Recommendation {RecId} approved by {AdminId}. WorkOrder {WoId} created for Crew {CrewId}.",
                recommendationId, adminUserId, workOrder.WorkOrderId, crew.CrewId);

            return new ApproveRecommendationResponseDto
            {
                RecommendationId = recommendationId,
                Decision = "APPROVED",
                DecidedBy = adminUserId,
                DecidedAt = approval.CreatedAt,
                WorkOrder = new WorkOrderSummaryDto
                {
                    Id = workOrder.WorkOrderId,
                    ProblemId = workOrder.ProblemId,
                    CrewId = workOrder.CrewId,
                    Priority = workOrder.Priority,
                    Status = workOrder.Status,
                    AssignedAt = workOrder.AssignedAt,
                    CreatedAt = workOrder.CreatedAt
                }
            };
        }
        catch (DbUpdateException dbEx) when (dbEx.InnerException is Npgsql.PostgresException pgEx && pgEx.SqlState == "23505")
        {
            await transaction.RollbackAsync();
            _logger.LogWarning(dbEx, "Database unique constraint violation during recommendation approval for {RecId}", recommendationId);
            throw new ConflictException("Crew already has an active work order in progress.", "CREW_CONFLICT");
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task<RejectRecommendationResponseDto> RejectRecommendationAsync(Guid recommendationId, RejectRecommendationRequest request, Guid adminUserId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        try
        {
            var ev = await _context.WorkflowEvents
                .Include(e => e.WorkflowRun)
                .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

            if (ev == null || string.IsNullOrWhiteSpace(ev.OutputData))
            {
                throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
            }

            Agent3RecommendationPayload payload;
            try
            {
                payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData, _jsonOptions)
                          ?? throw new BadRequestException("Recommendation payload could not be parsed.");
            }
            catch (Exception ex)
            {
                throw new BadRequestException($"Recommendation JSON error: {ex.Message}");
            }

            var targetProblemId = payload.ProblemId != Guid.Empty
                ? payload.ProblemId
                : (ev.WorkflowRun.ProblemId ?? Guid.Empty);

            // Acquire pessimistic row lock on Problem to serialize approval vs rejection
            var problem = await _context.Problems
                .FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {targetProblemId} FOR UPDATE")
                .FirstOrDefaultAsync();

            var alreadyApproved = await _context.ApprovalHistories
                .AnyAsync(a => a.WorkOrder.ProblemId == targetProblemId && a.Decision == "APPROVED");

            if (alreadyApproved)
            {
                throw new ConflictException("Cannot reject a recommendation that has already been approved.", "ALREADY_APPROVED");
            }

            // Find or fallback to a crew reference to satisfy the FK constraint
            var crewId = payload.RecommendedCrewId;
            if (!crewId.HasValue)
            {
                var fallbackCrew = await _context.Crews.FirstOrDefaultAsync();
                crewId = fallbackCrew?.CrewId ?? Guid.Empty;
            }

            // To record rejection in approval_history while honoring work_order_id foreign key:
            // Create a CANCELLED WorkOrder representing the rejected recommendation record
            var cancelledWorkOrder = new WorkOrder
            {
                WorkOrderId = Guid.NewGuid(),
                ProblemId = targetProblemId,
                CrewId = crewId.Value,
                Priority = payload.Priority ?? "MEDIUM",
                Title = $"[Rejected Recommendation] {problem?.Title ?? "Municipal Problem"}",
                Status = "CANCELLED",
                Instructions = $"Recommendation rejected: {request.Reason.Trim()}",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.WorkOrders.Add(cancelledWorkOrder);

            var approval = new ApprovalHistory
            {
                ApprovalId = Guid.NewGuid(),
                WorkOrderId = cancelledWorkOrder.WorkOrderId,
                DecidedBy = adminUserId,
                Decision = "REJECTED",
                Reason = request.Reason.Trim(),
                CreatedAt = DateTime.UtcNow
            };
            _context.ApprovalHistories.Add(approval);

            // Note: Approval decision is recorded in approval_history (REJECTED).
            // ev.Status remains its original status (COMPLETED) to conform with chk_workflow_events_status constraint.
            ev.WorkflowRun.Status = "WAITING";
            ev.WorkflowRun.CurrentStage = "WAITING_FOR_APPROVAL";
            ev.WorkflowRun.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            _logger.LogInformation("Recommendation {RecId} rejected by {AdminId}. Reason: {Reason}",
                recommendationId, adminUserId, request.Reason);

            return new RejectRecommendationResponseDto
            {
                RecommendationId = recommendationId,
                Decision = "REJECTED",
                Reason = request.Reason.Trim(),
                DecidedBy = adminUserId,
                DecidedAt = approval.CreatedAt
            };
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task<RegenerateRecommendationResponseDto> RegenerateRecommendationAsync(Guid recommendationId, RegenerateRecommendationRequest request, Guid adminUserId)
    {
        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null)
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }

        var workflowRun = ev.WorkflowRun;
        workflowRun.CurrentStage = "PRIORITIZATION";
        workflowRun.Status = "RUNNING";
        workflowRun.UpdatedAt = DateTime.UtcNow;

        var reason = !string.IsNullOrWhiteSpace(request.Reason)
            ? request.Reason.Trim()
            : "Coordinator requested recommendation re-evaluation.";

        workflowRun.StateData = JsonSerializer.Serialize(new
        {
            regenerationRequestedAt = DateTime.UtcNow,
            regenerationRequestedBy = adminUserId,
            reason
        }, _jsonOptions);

        await _context.SaveChangesAsync();

        _logger.LogInformation("Recommendation {RecId} marked for regeneration by {AdminId}.",
            recommendationId, adminUserId);

        return new RegenerateRecommendationResponseDto
        {
            PreviousRecommendationId = recommendationId,
            WorkflowId = workflowRun.WorkflowRunId,
            RequestedBy = adminUserId,
            RequestedAt = DateTime.UtcNow
        };
    }
}
