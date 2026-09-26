using System.Text.Json;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Npgsql;

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

        var recommendationIds = allEvents.Select(e => e.WorkflowEventId).ToList();
        var approvals = await _context.ApprovalHistories
            .AsNoTracking()
            .Where(a => a.RecommendationId.HasValue && recommendationIds.Contains(a.RecommendationId.Value))
            .ToListAsync();
        var approvalDict = approvals
            .GroupBy(a => a.RecommendationId!.Value)
            .ToDictionary(
                g => g.Key,
                g => g.OrderByDescending(a => a.CreatedAt).ThenByDescending(a => a.ApprovalId).First().Decision);

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
            if (approvalDict.TryGetValue(ev.WorkflowEventId, out var decision))
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

        if (ev == null || ev.Stage != "PRIORITIZATION" || string.IsNullOrWhiteSpace(ev.OutputData))
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
            .AsNoTracking()
            .Where(a => a.RecommendationId == recommendationId)
            .OrderByDescending(a => a.CreatedAt)
            .ThenByDescending(a => a.ApprovalId)
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
        await using var transaction = await _context.Database.BeginTransactionAsync();
        await LockRowAsync("SELECT 1 FROM workflow_events WHERE workflow_event_id = @id FOR UPDATE", recommendationId);

        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
                .ThenInclude(r => r.Problem)
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null || ev.Stage != "PRIORITIZATION" || string.IsNullOrWhiteSpace(ev.OutputData))
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }

        var reviewDecision = await _context.ApprovalHistories
            .Where(a => a.RecommendationId == recommendationId)
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => a.Decision)
            .FirstOrDefaultAsync();

        if (reviewDecision is "APPROVED" or "REJECTED")
        {
            throw new ConflictException("Cannot edit a recommendation that has already been reviewed.", "ALREADY_REVIEWED");
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

        var beforeData = ev.OutputData;
        var afterData = JsonSerializer.Serialize(payload, _jsonOptions);
        ev.OutputData = afterData;
        ev.ValidationResult = JsonSerializer.Serialize(validation, _jsonOptions);
        ev.CompletedAt = DateTime.UtcNow;

        _context.ActivityHistories.Add(new ActivityHistory
        {
            ActivityId = Guid.NewGuid(),
            ActorUserId = adminUserId,
            Action = "RECOMMENDATION_EDITED",
            RecommendationId = recommendationId,
            BeforeData = beforeData,
            AfterData = afterData,
            Note = request.EditReason.Trim(),
            CreatedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();
        await transaction.CommitAsync();

        var updated = await GetRecommendationByIdAsync(recommendationId);
        return updated!;
    }

    public async Task<ApproveRecommendationResponseDto> ApproveRecommendationAsync(Guid recommendationId, ApproveRecommendationRequest request, Guid adminUserId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync();
        await LockRowAsync("SELECT 1 FROM workflow_events WHERE workflow_event_id = @id FOR UPDATE", recommendationId);

        // 1. Recommendation exists
        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null || ev.Stage != "PRIORITIZATION" || string.IsNullOrWhiteSpace(ev.OutputData))
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }

        var existingDecision = await _context.ApprovalHistories
            .Where(a => a.RecommendationId == recommendationId)
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => a.Decision)
            .FirstOrDefaultAsync();

        if (existingDecision is "APPROVED" or "REJECTED")
        {
            throw new ConflictException("This recommendation has already been reviewed.", "ALREADY_REVIEWED");
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

        await LockRowAsync("SELECT 1 FROM problems WHERE problem_id = @id FOR UPDATE", targetProblemId);

        // 2. Problem exists
        var problem = await _context.Problems.FindAsync(targetProblemId);
        if (problem == null)
        {
            throw new NotFoundException("Associated problem not found.", "PROBLEM_NOT_FOUND");
        }

        // 3. Report <-> Problem links are valid (has at least 1 linked report)
        var hasLinkedReports = await _context.Reports.AnyAsync(r => r.ProblemId == targetProblemId);
        if (!hasLinkedReports)
        {
            throw new ValidationException("Problem has no linked resident reports.");
        }

        // 4. Priority is valid enum
        var validPriorities = new[] { "LOW", "MEDIUM", "HIGH", "CRITICAL" };
        if (string.IsNullOrWhiteSpace(payload.Priority) || !validPriorities.Contains(payload.Priority.ToUpperInvariant()))
        {
            throw new ValidationException($"Priority '{payload.Priority}' is not a valid priority level.");
        }

        // 5. Crew exists
        if (!payload.RecommendedCrewId.HasValue)
        {
            throw new ValidationException("No crew was recommended for dispatch.");
        }

        await LockRowAsync("SELECT 1 FROM crews WHERE crew_id = @id FOR UPDATE", payload.RecommendedCrewId.Value);
        var crew = await _context.Crews.FindAsync(payload.RecommendedCrewId.Value);
        if (crew == null)
        {
            throw new ValidationException($"Recommended crew '{payload.RecommendedCrewId.Value}' does not exist.");
        }

        // 6. Crew type matches required crew type
        if (!string.Equals(crew.CrewType, payload.RequiredCrewType, StringComparison.OrdinalIgnoreCase))
        {
            throw new ValidationException($"Crew type '{crew.CrewType}' does not match required specialty '{payload.RequiredCrewType}'.");
        }

        // 7. Crew status == "AVAILABLE" (checked at approval time)
        if (!string.Equals(crew.Status, "AVAILABLE", StringComparison.OrdinalIgnoreCase))
        {
            throw new ConflictException(
                $"Recommended crew '{crew.CrewName}' is currently {crew.Status}.",
                "CREW_NOT_AVAILABLE");
        }

        // 8. No conflicting active WorkOrder for this crew
        var hasConflict = await _context.WorkOrders.AnyAsync(w =>
            w.CrewId == crew.CrewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"));

        if (hasConflict)
        {
            throw new ConflictException(
                $"Crew '{crew.CrewName}' already has an active work order in progress.",
                "CREW_CONFLICT");
        }

        // 9. The Problem has no previously approved WorkOrder
        var alreadyApproved = await _context.ApprovalHistories
            .AnyAsync(a => a.WorkOrder != null && a.WorkOrder.ProblemId == targetProblemId && a.Decision == "APPROVED");

        if (alreadyApproved)
        {
            throw new ConflictException(
                "This recommendation has already been approved.",
                "ALREADY_APPROVED");
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
            RecommendationId = recommendationId,
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
            RecommendationId = recommendationId,
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

        try
        {
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (DbUpdateException ex) when (IsDispatchUniquenessConflict(ex))
        {
            throw new ConflictException("The recommendation or crew was assigned by another request. Refresh and try again.", "DISPATCH_CONFLICT");
        }

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

    public async Task<RejectRecommendationResponseDto> RejectRecommendationAsync(Guid recommendationId, RejectRecommendationRequest request, Guid adminUserId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync();
        await LockRowAsync("SELECT 1 FROM workflow_events WHERE workflow_event_id = @id FOR UPDATE", recommendationId);

        var ev = await _context.WorkflowEvents
            .Include(e => e.WorkflowRun)
            .FirstOrDefaultAsync(e => e.WorkflowEventId == recommendationId);

        if (ev == null || ev.Stage != "PRIORITIZATION" || string.IsNullOrWhiteSpace(ev.OutputData))
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }

        var existingDecision = await _context.ApprovalHistories
            .Where(a => a.RecommendationId == recommendationId)
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => a.Decision)
            .FirstOrDefaultAsync();

        if (existingDecision is "APPROVED" or "REJECTED")
        {
            throw new ConflictException("This recommendation has already been reviewed.", "ALREADY_REVIEWED");
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

        await LockRowAsync("SELECT 1 FROM problems WHERE problem_id = @id FOR UPDATE", targetProblemId);

        var alreadyApproved = await _context.ApprovalHistories
            .AnyAsync(a => a.WorkOrder != null && a.WorkOrder.ProblemId == targetProblemId && a.Decision == "APPROVED");

        if (alreadyApproved)
        {
            throw new ConflictException("Cannot reject a recommendation that has already been approved.", "ALREADY_APPROVED");
        }

        var approval = new ApprovalHistory
        {
            ApprovalId = Guid.NewGuid(),
            WorkOrderId = null,
            RecommendationId = recommendationId,
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

        try
        {
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (DbUpdateException ex) when (IsDispatchUniquenessConflict(ex))
        {
            throw new ConflictException("This recommendation was reviewed by another request. Refresh and try again.", "ALREADY_REVIEWED");
        }

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

    private async Task LockRowAsync(string sql, Guid id)
    {
        await using var command = _context.Database.GetDbConnection().CreateCommand();
        command.Transaction = _context.Database.CurrentTransaction!.GetDbTransaction();
        command.CommandText = sql;

        var parameter = command.CreateParameter();
        parameter.ParameterName = "id";
        parameter.Value = id;
        command.Parameters.Add(parameter);

        await command.ExecuteScalarAsync();
    }

    private static bool IsDispatchUniquenessConflict(DbUpdateException exception)
    {
        if (exception.InnerException is not PostgresException postgresException ||
            postgresException.SqlState != PostgresErrorCodes.UniqueViolation)
        {
            return false;
        }

        return postgresException.ConstraintName is
            "idx_work_orders_recommendation_id" or
            "ux_work_orders_active_crew" or
            "ux_work_orders_active_problem" or
            "ux_approval_history_terminal_recommendation";
    }
}
