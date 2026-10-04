using System.Data;
using System.Text.Json;
using System.Text.Json.Nodes;
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

public partial class DispatchService : IDispatchService
{
    private readonly AppDbContext _context;
    private readonly ILogger<DispatchService> _logger;
    private readonly JsonSerializerOptions _jsonOptions;
    private readonly AiReviewService _review;

    public DispatchService(AppDbContext context, ILogger<DispatchService> logger, AiReviewService review)
    {
        _context = context;
        _review = review;
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
        if (query.ReviewBucket is "READY" or "PROCESSING" or "NEEDS_ATTENTION")
        {
            eventsQuery = eventsQuery.Where(e => e.WorkflowRun.CurrentRecommendationId == e.WorkflowEventId);
            eventsQuery = eventsQuery.Where(e => !_context.ApprovalHistories.Any(a => a.RecommendationId == e.WorkflowEventId &&
                (a.Decision == "APPROVED" || a.Decision == "REJECTED")));
            if (query.ReviewBucket == "PROCESSING")
                eventsQuery = eventsQuery.Where(e => _context.AiReviewJobs.Any(j => j.WorkflowRunId == e.WorkflowRunId && (j.Status == "QUEUED" || j.Status == "RUNNING")));
            else
                eventsQuery = eventsQuery.Where(e => !_context.AiReviewJobs.Any(j => j.WorkflowRunId == e.WorkflowRunId && (j.Status == "QUEUED" || j.Status == "RUNNING")));
        }
        else if (query.ReviewBucket == "DECIDED")
            eventsQuery = eventsQuery.Where(e => _context.ApprovalHistories.Any(a => a.RecommendationId == e.WorkflowEventId &&
                (a.Decision == "APPROVED" || a.Decision == "REJECTED")));
        eventsQuery = isAscending
            ? eventsQuery.OrderBy(e => e.StartedAt).ThenBy(e => e.WorkflowEventId)
            : eventsQuery.OrderByDescending(e => e.StartedAt).ThenByDescending(e => e.WorkflowEventId);

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
            var reviewMetadata = ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData);
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
                (query.ReviewDecision.Equals("PENDING", StringComparison.OrdinalIgnoreCase) ? reviewDecision != null :
                !string.Equals(reviewDecision, query.ReviewDecision.Trim(), StringComparison.OrdinalIgnoreCase)))
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

            var search = query.Search?.Trim();
            if (!string.IsNullOrWhiteSpace(query.Category) && !string.Equals(problem?.Category ?? payload.RequiredCrewType, query.Category, StringComparison.OrdinalIgnoreCase)) continue;
            if (!string.IsNullOrWhiteSpace(search) && !($"{problem?.Title} {problem?.Address} {problem?.Category ?? payload.RequiredCrewType} {crewName} {payload.ProblemId}".Contains(search, StringComparison.OrdinalIgnoreCase))) continue;
            var item = new RecommendationListItemDto
            {
                RecommendationId = ev.WorkflowEventId,
                Revision = ev.Revision,
                IsCurrent = ev.WorkflowRun.CurrentRecommendationId == ev.WorkflowEventId,
                PreviousRecommendationId = ev.PreviousRecommendationId,
                CanApprove = !await _context.ApprovalHistories.AnyAsync(a => a.RecommendationId == ev.WorkflowEventId && (a.Decision == "APPROVED" || a.Decision == "REJECTED")) && await _review.CanApproveAsync(ev),
                Origin = reviewMetadata?.Origin, EditedBy = reviewMetadata?.EditedBy, EditedAt = reviewMetadata?.EditedAt,
                RequiresResponsibilityAcknowledgement = await _review.GetHumanOverrideAsync(ev) != null,
                LatestJob = await LatestReviewJobAsync(ev.WorkflowRunId),
                ProblemId = payload.ProblemId != Guid.Empty ? payload.ProblemId : (ev.WorkflowRun.ProblemId ?? Guid.Empty),
                ProblemTitle = problem?.Title ?? string.Empty,
                Address = problem?.Address,
                Category = problem?.Category ?? payload.RequiredCrewType,
                Priority = payload.Priority,
                PriorityScore = payload.PriorityScore,
                PriorityReasons = payload.PriorityReasons ?? new(),
                RequiredCrewType = payload.RequiredCrewType,
                RecommendedCrewId = payload.RecommendedCrewId,
                RecommendedCrewName = crewName,
                RecommendationReason = payload.RecommendationReason,
                EstimatedDurationMinutes = payload.EstimatedDurationMinutes ?? problem?.EstimatedDurationMinutes,
                DistanceKm = payload.DistanceKm,
                EstimatedTravelMinutes = payload.EstimatedTravelMinutes,
                DispatchStrategy = payload.DispatchStrategy ?? "STANDARD_DISPATCH",
                Validation = validation,
                ReviewDecision = reviewDecision,
                CreatedAt = ev.StartedAt
            };
            SetDisplayState(ev, item);
            if (!string.IsNullOrWhiteSpace(query.ReviewBucket) && query.ReviewBucket != "ALL" && item.ReviewBucket != query.ReviewBucket) continue;
            listItems.Add(item);
        }

        var totalItems = listItems.Count;
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = Math.Clamp(query.PageSize < 1 ? 20 : query.PageSize, 1, 100);

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
        var reviewMetadata = ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData);

        var detail = new RecommendationDetailDto
        {
            RecommendationId = ev.WorkflowEventId,
                Revision = ev.Revision,
                IsCurrent = ev.WorkflowRun.CurrentRecommendationId == ev.WorkflowEventId,
                PreviousRecommendationId = ev.PreviousRecommendationId,
                CanApprove = !await _context.ApprovalHistories.AnyAsync(a => a.RecommendationId == ev.WorkflowEventId && (a.Decision == "APPROVED" || a.Decision == "REJECTED")) && await _review.CanApproveAsync(ev),
                Origin = reviewMetadata?.Origin, EditedBy = reviewMetadata?.EditedBy, EditedAt = reviewMetadata?.EditedAt,
                RequiresResponsibilityAcknowledgement = await _review.GetHumanOverrideAsync(ev) != null,
                LatestJob = await LatestReviewJobAsync(ev.WorkflowRunId),
            OriginalOutputData = ev.OriginalOutputData,
            JobHistory = (await _context.AiReviewJobs.AsNoTracking().Where(j => j.WorkflowRunId == ev.WorkflowRunId)
                .OrderBy(j => j.CreatedAt).ThenBy(j => j.Id).ToListAsync()).Select(ReviewJobDto.From).ToList(),
            ProblemId = problemId,
            ProblemTitle = problem?.Title ?? string.Empty,
            ProblemDescription = problem?.Description,
            Category = problem?.Category ?? payload.RequiredCrewType,
            Latitude = problem?.Latitude ?? 0,
            Longitude = problem?.Longitude ?? 0,
            Address = problem?.Address,
            ReportCount = problem?.Reports.Count ?? 0,
            ReportDescriptions = reportDescriptions,
            ValidationHistory = await _context.WorkflowEvents.AsNoTracking().Where(e => e.WorkflowRunId == ev.WorkflowRunId && e.Stage == "VALIDATION")
                .OrderBy(e => e.StartedAt).Select(e => new ValidationAttemptDto(e.WorkflowEventId, e.StartedAt, e.CompletedAt, e.Status, e.ValidationResult)).ToListAsync(),
            HumanOverrideApproval = AiReviewService.Obj(ev.InputData)["humanOverrideApproval"] as JsonObject,
            EditHistory = await _context.ActivityHistories.AsNoTracking().Where(a => a.RecommendationId == recommendationId && a.Action == "RECOMMENDATION_EDITED")
                .OrderBy(a => a.CreatedAt).Select(a => new RecommendationEditDto(a.ActivityId, a.CreatedAt, a.Note, a.BeforeData, a.AfterData, a.ActorUserId)).ToListAsync(),
            History = await _context.WorkflowEvents.AsNoTracking().Where(e => e.WorkflowRunId == ev.WorkflowRunId && e.Stage == "PRIORITIZATION")
                .OrderBy(e => e.StartedAt).Select(e => new ReviewHistoryItem(e.WorkflowEventId, e.PreviousRecommendationId, e.Revision, e.StartedAt, e.OutputData, e.ValidationResult, e.OriginalOutputData)).ToListAsync(),
            Priority = payload.Priority,
            PriorityScore = payload.PriorityScore,
            PriorityReasons = payload.PriorityReasons ?? new(),
            RequiredCrewType = payload.RequiredCrewType,
            RecommendedCrewId = payload.RecommendedCrewId,
            RecommendedCrewName = crewName,
            RecommendedCrewStatus = crewStatus,
            RecommendationReason = payload.RecommendationReason,
            EstimatedDurationMinutes = payload.EstimatedDurationMinutes ?? problem?.EstimatedDurationMinutes,
            DistanceKm = payload.DistanceKm,
            EstimatedTravelMinutes = payload.EstimatedTravelMinutes,
            DispatchStrategy = payload.DispatchStrategy ?? "STANDARD_DISPATCH",
            Validation = validation,
            ReviewDecision = approval?.Decision,
            ReviewReason = approval?.Reason,
            ReviewedBy = approval?.DecidedBy,
            ReviewedAt = approval?.CreatedAt,
            WorkOrderId = approval?.WorkOrderId,
            CreatedAt = ev.StartedAt
        };
        SetDisplayState(ev, detail);
        return detail;
    }

    public async Task<RecommendationDetailDto> EditRecommendationAsync(Guid recommendationId, EditRecommendationRequest request, Guid adminUserId)
    {
        if (string.IsNullOrWhiteSpace(request.EditReason) || request.EditReason.Length > 4000) throw new BadRequestException("An edit reason of 1–4000 characters is required.");
        await using var tx = await _context.Database.BeginTransactionAsync();
        var ev = await _review.LockRecommendationAsync(recommendationId, request.ExpectedRevision);
        var original = AiReviewService.Obj(ev.OutputData);
        var payload = original.DeepClone().AsObject();
        if (request.Priority != null) payload["priority"] = request.Priority.Trim().ToUpperInvariant();
        if (request.PriorityScore.HasValue) payload["priorityScore"] = request.PriorityScore.Value;
        if (request.RecommendedCrewId.HasValue) payload["recommendedCrewId"] = request.RecommendedCrewId.Value.ToString();
        if (request.RequiredCrewType != null) payload["requiredCrewType"] = request.RequiredCrewType.Trim().ToUpperInvariant();
        if (request.PriorityReasons != null) payload["priorityReasons"] = JsonSerializer.SerializeToNode(request.PriorityReasons, _jsonOptions);
        if (request.RecommendationReason != null) payload["recommendationReason"] = request.RecommendationReason.Trim();
        if (!AiReviewService.HasMeaningfulEdit(original, payload))
        {
            // Preserve the exact revision, provenance and validation on a no-op save.
            await tx.CommitAsync();
            return (await GetRecommendationByIdAsync(recommendationId))!;
        }
        var before = ev.OutputData;
        var beforeRevision = ev.Revision;
        var beforeMetadata = ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData);
        ev.OriginalOutputData ??= before;
        ev.OutputData = payload.ToJsonString(_jsonOptions);
        ev.Revision++; ev.ValidatedRevision = null; ev.EvidenceHash = null;
        ev.EvidenceRequest = null;
        var overrideReview = AiReviewService.Failure("Human override: Agent 4 was not run on this revision. Coordinator acknowledgement and backend business checks are required.", "NOT_RUN");
        overrideReview["policyVersion"] = "human-override-v1";
        overrideReview["suggestedAction"] = "HUMAN_APPROVAL_REVIEW";
        overrideReview["findings"] = new JsonArray();
        ev.ValidationResult = overrideReview.ToJsonString();
        ev.WorkflowRun.Status = "WAITING"; ev.WorkflowRun.CurrentStage = "WAITING_FOR_APPROVAL";
        ev.WorkflowRun.CompletedAt = null; ev.WorkflowRun.UpdatedAt = DateTime.UtcNow;
        var editedAt = DateTimeOffset.UtcNow;
        // This provenance must also match the exact edit audit before it exempts AI review.
        ev.InputData = ReviewMetadataJson.Write(ev.InputData, new RecommendationReviewMetadata {
            SchemaVersion = ReviewMetadataJson.CurrentVersion, Origin = ReviewOrigins.HumanOverride,
            Revision = ev.Revision, JobId = beforeMetadata?.JobId, ChainId = beforeMetadata?.ChainId,
            EditedBy = adminUserId, EditedAt = editedAt });
        var state = AiReviewService.Obj(ev.WorkflowRun.StateData);
        state["priorityAnalysis"] = payload.DeepClone();
        state["recommendations"] = new JsonArray(payload.DeepClone());
        state["safetyValidation"] = overrideReview.DeepClone();
        ev.WorkflowRun.StateData = state.ToJsonString(_jsonOptions);
        AiReviewService.SetReviewProgress(ev.WorkflowRun, ev, "NEEDS_ATTENTION", "Human override requires coordinator acknowledgement and backend approval checks.");
        _context.ActivityHistories.Add(new ActivityHistory { ActivityId = Guid.NewGuid(), ActorUserId = adminUserId,
            Action = "RECOMMENDATION_EDITED", RecommendationId = recommendationId,
            BeforeData = ReviewMetadataJson.Write(before, new RecommendationAuditMetadata {
                SchemaVersion = ReviewMetadataJson.CurrentVersion, Revision = beforeRevision, Origin = beforeMetadata?.Origin }),
            AfterData = ReviewMetadataJson.Write(ev.OutputData, new RecommendationAuditMetadata {
                SchemaVersion = ReviewMetadataJson.CurrentVersion, Revision = ev.Revision, Origin = ReviewOrigins.HumanOverride }),
            Note = request.EditReason.Trim(), CreatedAt = editedAt.UtcDateTime });
        await _context.SaveChangesAsync(); await tx.CommitAsync();
        return (await GetRecommendationByIdAsync(recommendationId))!;
    }

    public async Task<ApproveRecommendationResponseDto> ApproveRecommendationAsync(Guid recommendationId, ApproveRecommendationRequest request, Guid adminUserId)
    {
        await using var tx = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        try
        {
            var ev = await _review.LockRecommendationAsync(recommendationId, request.ExpectedRevision);
            var humanOverride = await _review.GetHumanOverrideAsync(ev);
            if (humanOverride != null && (!request.AcknowledgeHumanOverrideResponsibility ||
                string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 4000))
                throw new BadRequestException("Acknowledge responsibility and provide an approval reason (1–4000 characters) for this human override.");
            if (!AiReviewService.ApprovalFieldsValid(AiReviewService.Obj(ev.OutputData)))
                throw new BadRequestException("Recommendation fields do not satisfy dispatch business rules.");
            var payload = JsonSerializer.Deserialize<Agent3RecommendationPayload>(ev.OutputData!, _jsonOptions)
                ?? throw new BadRequestException("Recommendation payload is missing.");
            var pid = payload.ProblemId;
            var problem = await _context.Problems.FromSqlInterpolated($"SELECT * FROM problems WHERE problem_id = {pid} FOR UPDATE").SingleOrDefaultAsync()
                ?? throw new NotFoundException("Problem not found.", "PROBLEM_NOT_FOUND");
            if (ev.WorkflowRun.ProblemId != pid) throw new ConflictException("Problem association changed.", "STALE_RECOMMENDATION");
            if (!payload.RecommendedCrewId.HasValue) throw new BadRequestException("A crew is required.");
            var cid = payload.RecommendedCrewId.Value;
            var crew = await _context.Crews.FromSqlInterpolated($"SELECT * FROM crews WHERE crew_id = {cid} FOR UPDATE").SingleOrDefaultAsync()
                ?? throw new BadRequestException("Crew not found.");
            var evidenceIds = await _review.GetApprovalReportIdsAsync(ev)
                ?? throw new ConflictException("Authorized source report context is missing or invalid. Review the Problem/report links.", "REVIEW_INPUT_REQUIRED");
            await _context.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE report_id = ANY({evidenceIds}) ORDER BY report_id FOR UPDATE").ToListAsync();
            var reports = await _context.Reports.FromSqlInterpolated($"SELECT * FROM reports WHERE problem_id = {pid} ORDER BY report_id FOR UPDATE").ToListAsync();
            if (!reports.Any(r => r.ReportId == ev.WorkflowRun.ReportId && r.Status != "CANCELLED") || !await _review.CanApproveAsync(ev))
                throw new ConflictException(humanOverride == null
                    ? "Passing validation and current dispatch business checks are required. Refresh and revalidate."
                    : "Human override fails current dispatch business checks. Check report links, crew specialty/availability and active work.", "APPROVAL_CHECKS_FAILED");
            var validScore = payload.Priority switch { "LOW" => payload.PriorityScore is >= 0 and <= 29,
                "MEDIUM" => payload.PriorityScore is >= 30 and <= 59, "HIGH" => payload.PriorityScore is >= 60 and <= 84,
                "CRITICAL" => payload.PriorityScore is >= 85 and <= 100, _ => false };
            if (!validScore) throw new BadRequestException("Priority does not match its score.");
            var now = DateTime.UtcNow;
            var order = new WorkOrder { WorkOrderId = Guid.NewGuid(), RecommendationId = recommendationId,
                ProblemId = pid, CrewId = cid, Priority = payload.Priority, Title = problem.Title, Status = "ASSIGNED",
                Instructions = string.IsNullOrWhiteSpace(request.Instructions) ? $"Resolve {problem.Title} at {problem.Address}." : request.Instructions.Trim(),
                AssignedAt = now, CreatedAt = now, UpdatedAt = now };
            _context.WorkOrders.Add(order);
            var approvalId = Guid.NewGuid();
            _context.ApprovalHistories.Add(new ApprovalHistory { ApprovalId = approvalId, RecommendationId = recommendationId,
                WorkOrderId = order.WorkOrderId, DecidedBy = adminUserId, Decision = "APPROVED", Reason = request.Reason?.Trim(), CreatedAt = now });
            if (humanOverride != null)
            {
                // Approval acknowledgement uses existing recommendation JSON and the
                // terminal approval row. Do not add unsupported activity-history actions.
                var input = AiReviewService.Obj(ev.InputData);
                input["humanOverrideApproval"] = new JsonObject {
                        ["recommendationId"] = recommendationId.ToString(), ["revision"] = ev.Revision,
                        ["origin"] = ReviewOrigins.HumanOverride, ["editedBy"] = humanOverride.EditedBy?.ToString(),
                        ["editedAt"] = JsonSerializer.SerializeToNode(humanOverride.EditedAt, _jsonOptions),
                        ["acknowledgedBy"] = adminUserId.ToString(), ["acknowledgedAt"] = now.ToString("O"),
                        ["responsibilityAcknowledged"] = true, ["policyVersion"] = "human-override-v1",
                        ["approvalId"] = approvalId.ToString(), ["reason"] = request.Reason!.Trim(),
                        ["workOrderId"] = order.WorkOrderId.ToString(), ["reportIds"] = JsonSerializer.SerializeToNode(evidenceIds),
                        ["backendBusinessChecksPassed"] = true };
                ev.InputData = input.ToJsonString(_jsonOptions);
            }
            crew.Status = "BUSY"; crew.UpdatedAt = now;
            problem.Status = "ASSIGNED"; problem.Priority = payload.Priority; problem.PriorityScore = payload.PriorityScore; problem.UpdatedAt = now;
            foreach (var report in reports.Where(r => r.Status != "CANCELLED")) { report.Status = "ASSIGNED"; report.UpdatedAt = now; }
            ev.WorkflowRun.Status = "RUNNING"; ev.WorkflowRun.CurrentStage = "WORK_EXECUTION"; ev.WorkflowRun.CompletedAt = null; ev.WorkflowRun.UpdatedAt = now;
            await _context.SaveChangesAsync(); await tx.CommitAsync();
            return new ApproveRecommendationResponseDto { RecommendationId = recommendationId, Decision = "APPROVED", DecidedBy = adminUserId,
                DecidedAt = now, WorkOrder = new WorkOrderSummaryDto { Id = order.WorkOrderId, ProblemId = pid, CrewId = cid,
                    Priority = order.Priority, Status = order.Status, AssignedAt = now, CreatedAt = now } };
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException pg && pg.SqlState == "23505")
        {
            throw new ConflictException("Another request already assigned this recommendation, Problem or crew.", "DISPATCH_CONFLICT");
        }
    }

    public async Task<RejectRecommendationResponseDto> RejectRecommendationAsync(Guid recommendationId, RejectRecommendationRequest request, Guid adminUserId)
    {
        if (string.IsNullOrWhiteSpace(request.Reason)) throw new BadRequestException("A rejection reason is required.");
        await using var tx = await _context.Database.BeginTransactionAsync();
        var ev = await _review.LockRecommendationAsync(recommendationId, request.ExpectedRevision);
        var now = DateTime.UtcNow;
        _context.ApprovalHistories.Add(new ApprovalHistory { ApprovalId = Guid.NewGuid(), RecommendationId = recommendationId,
            WorkOrderId = null, DecidedBy = adminUserId, Decision = "REJECTED", Reason = request.Reason.Trim(), CreatedAt = now });
        ev.WorkflowRun.Status = "CANCELLED"; ev.WorkflowRun.CompletedAt = now; ev.WorkflowRun.UpdatedAt = now;
        await _context.SaveChangesAsync(); await tx.CommitAsync();
        return new RejectRecommendationResponseDto { RecommendationId = recommendationId, Decision = "REJECTED", Reason = request.Reason.Trim(), DecidedBy = adminUserId, DecidedAt = now };
    }

    public async Task<RegenerateRecommendationResponseDto> RegenerateRecommendationAsync(Guid recommendationId, RegenerateRecommendationRequest request, Guid adminUserId)
    {
        var job = await _review.EnqueueAsync(recommendationId, request, adminUserId, "REGENERATE");
        return new RegenerateRecommendationResponseDto { JobId = job.Id, Status = job.Status,
            StatusUrl = $"/api/dispatch/review-jobs/{job.Id}", PreviousRecommendationId = recommendationId,
            WorkflowId = job.WorkflowRunId, RequestedBy = job.RequestedBy, RequestedAt = job.CreatedAt };
    }
}
