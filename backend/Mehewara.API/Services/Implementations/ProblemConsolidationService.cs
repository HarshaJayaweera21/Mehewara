using System.Text.Json;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems.Consolidation;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class ProblemConsolidationService : IProblemConsolidationService
{
    private static readonly HashSet<string> AllowedCategories = new(StringComparer.OrdinalIgnoreCase)
    {
        "DRAINAGE", "ROAD", "WASTE", "ELECTRICAL", "ENVIRONMENT"
    };

    private static readonly HashSet<string> AllowedDecisions = new(StringComparer.OrdinalIgnoreCase)
    {
        "LINK_EXISTING", "CREATE_NEW", "UNCERTAIN"
    };

    private readonly AppDbContext _context;
    private readonly ILogger<ProblemConsolidationService> _logger;

    public ProblemConsolidationService(
        AppDbContext context,
        ILogger<ProblemConsolidationService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<ConsolidationOutcomeDto> ApplyConsolidationAsync(
        ProblemConsolidationResultDto consolidationResult,
        Guid? workflowRunId = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(consolidationResult);

        var outcome = new ConsolidationOutcomeDto
        {
            ReportId = consolidationResult.ReportId,
            Decision = consolidationResult.Decision
        };

        var decision = consolidationResult.Decision?.Trim().ToUpperInvariant() ?? string.Empty;

        // 1. Validate Decision Enum
        if (!AllowedDecisions.Contains(decision))
        {
            outcome.Success = false;
            outcome.ValidationStatus = "FAILED";
            outcome.ValidationErrors.Add($"Invalid decision '{consolidationResult.Decision}'. Allowed values: {string.Join(", ", AllowedDecisions)}");
            _logger.LogWarning("Consolidation rejected: invalid decision '{Decision}' for Report {ReportId}", consolidationResult.Decision, consolidationResult.ReportId);
            return outcome;
        }

        // 2. Validate Incoming Report Existence
        var report = await _context.Reports
            .Include(r => r.Photos)
            .FirstOrDefaultAsync(r => r.ReportId == consolidationResult.ReportId, cancellationToken);

        if (report == null)
        {
            outcome.Success = false;
            outcome.ValidationStatus = "FAILED";
            outcome.ValidationErrors.Add($"Incoming report with ID {consolidationResult.ReportId} was not found.");
            _logger.LogWarning("Consolidation rejected: Report {ReportId} not found", consolidationResult.ReportId);
            return outcome;
        }

        // 3. Conflict Guard: Report already assigned to a different problem
        if (report.ProblemId.HasValue)
        {
            if (decision == "LINK_EXISTING" && consolidationResult.ProblemId == report.ProblemId.Value)
            {
                _logger.LogInformation("Report {ReportId} is already linked to Problem {ProblemId}. Confirming existing link.", report.ReportId, report.ProblemId.Value);
            }
            else
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.Add($"Report {report.ReportId} is already assigned to Problem {report.ProblemId.Value}. Authoritative relationships cannot be overwritten by Agent 2.");
                _logger.LogWarning("Consolidation rejected: Conflict on Report {ReportId} already assigned to Problem {ExistingProblemId}", report.ReportId, report.ProblemId.Value);
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }
        }

        Guid? targetProblemId = null;
        Problem? targetProblem = null;

        // 4. Branch Logic based on Decision
        if (decision == "UNCERTAIN")
        {
            outcome.Success = true;
            outcome.ValidationStatus = "SAFE_FAILURE";
            outcome.ProblemId = null;
            _logger.LogInformation("Consolidation resulted in UNCERTAIN for Report {ReportId}. Recording safe outcome without DB mutation.", report.ReportId);

            await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
            return outcome;
        }

        if (decision == "LINK_EXISTING")
        {
            if (!consolidationResult.ProblemId.HasValue || consolidationResult.ProblemId.Value == Guid.Empty)
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.Add("ProblemId is required when decision is LINK_EXISTING.");
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }

            targetProblem = await _context.Problems
                .Include(p => p.Reports)
                .FirstOrDefaultAsync(p => p.ProblemId == consolidationResult.ProblemId.Value, cancellationToken);

            if (targetProblem == null)
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.Add($"Target problem with ID {consolidationResult.ProblemId.Value} was not found.");
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }

            if (string.Equals(targetProblem.Status, "RESOLVED", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(targetProblem.Status, "CLOSED", StringComparison.OrdinalIgnoreCase))
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.Add($"Target problem {targetProblem.ProblemId} has status '{targetProblem.Status}' and is not eligible for consolidation.");
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }

            targetProblemId = targetProblem.ProblemId;
            report.ProblemId = targetProblemId;
            report.UpdatedAt = DateTime.UtcNow;

            // Safely associate any unassigned related reports identified by Agent 2
            await AssociateUnassignedRelatedReportsAsync(consolidationResult.RelatedReportIds, report.ReportId, targetProblemId.Value, cancellationToken);
        }
        else if (decision == "CREATE_NEW")
        {
            if (consolidationResult.NewProblem == null)
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.Add("NewProblem candidate details are required when decision is CREATE_NEW.");
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }

            var newProb = consolidationResult.NewProblem;
            var validationErrors = ValidateNewProblemCandidate(newProb);
            if (validationErrors.Count > 0)
            {
                outcome.Success = false;
                outcome.ValidationStatus = "FAILED";
                outcome.ValidationErrors.AddRange(validationErrors);
                await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken);
                return outcome;
            }

            targetProblem = new Problem
            {
                ProblemId = Guid.NewGuid(),
                Title = newProb.Title.Trim(),
                Description = string.IsNullOrWhiteSpace(newProb.Description) ? null : newProb.Description.Trim(),
                Category = newProb.Category.Trim().ToUpperInvariant(),
                Latitude = newProb.Latitude,
                Longitude = newProb.Longitude,
                Address = string.IsNullOrWhiteSpace(newProb.Address) ? null : newProb.Address.Trim(),
                Status = "IDENTIFIED",
                Priority = null,
                PriorityScore = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Problems.Add(targetProblem);
            targetProblemId = targetProblem.ProblemId;

            report.ProblemId = targetProblemId;
            report.UpdatedAt = DateTime.UtcNow;

            // Safely associate any unassigned related reports identified by Agent 2
            await AssociateUnassignedRelatedReportsAsync(consolidationResult.RelatedReportIds, report.ReportId, targetProblemId.Value, cancellationToken);
        }

        // 5. Update WorkflowRun & Record WorkflowEvent
        var run = await RecordWorkflowEventAsync(workflowRunId, report.ReportId, consolidationResult, outcome, cancellationToken, targetProblemId);

        if (run != null && targetProblemId.HasValue)
        {
            run.ProblemId = targetProblemId;
            run.CurrentStage = "PRIORITIZATION";
            run.UpdatedAt = DateTime.UtcNow;
        }

        // 6. Commit Database Changes
        await _context.SaveChangesAsync(cancellationToken);

        outcome.Success = true;
        outcome.ValidationStatus = "PASSED";
        outcome.ProblemId = targetProblemId;

        // 7. Assemble Canonical ProblemContext for Agent 3 handoff
        if (targetProblem != null)
        {
            var linkedReportIds = await _context.Reports
                .Where(r => r.ProblemId == targetProblem.ProblemId)
                .Select(r => r.ReportId)
                .ToListAsync(cancellationToken);

            outcome.ProblemContext = new ProblemContextDto
            {
                ProblemId = targetProblem.ProblemId,
                Title = targetProblem.Title,
                Description = targetProblem.Description,
                Category = targetProblem.Category,
                Latitude = targetProblem.Latitude,
                Longitude = targetProblem.Longitude,
                Address = targetProblem.Address,
                Status = targetProblem.Status,
                RelatedReportIds = linkedReportIds,
                RelatedReportCount = linkedReportIds.Count,
                ReportedImpacts = new List<string>(),
                Hazards = new List<string>(),
                ConsolidationSummary = consolidationResult.Summary
            };
        }

        _logger.LogInformation("Consolidation applied successfully: Decision {Decision} for Report {ReportId} -> Problem {ProblemId}",
            decision, report.ReportId, targetProblemId);

        return outcome;
    }

    private static List<string> ValidateNewProblemCandidate(NewProblemCandidateDto newProb)
    {
        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(newProb.Title))
        {
            errors.Add("New problem title is required.");
        }
        else if (newProb.Title.Length > 200)
        {
            errors.Add("New problem title must not exceed 200 characters.");
        }

        if (string.IsNullOrWhiteSpace(newProb.Category) || !AllowedCategories.Contains(newProb.Category.Trim()))
        {
            errors.Add($"Invalid category '{newProb.Category}'. Allowed categories: {string.Join(", ", AllowedCategories)}");
        }

        if (newProb.Latitude < -90m || newProb.Latitude > 90m)
        {
            errors.Add("Latitude must be between -90 and 90 degrees.");
        }

        if (newProb.Longitude < -180m || newProb.Longitude > 180m)
        {
            errors.Add("Longitude must be between -180 and 180 degrees.");
        }

        return errors;
    }

    private async Task AssociateUnassignedRelatedReportsAsync(
        List<Guid>? relatedReportIds,
        Guid incomingReportId,
        Guid problemId,
        CancellationToken cancellationToken)
    {
        if (relatedReportIds == null || relatedReportIds.Count == 0) return;

        var otherCandidateIds = relatedReportIds
            .Where(id => id != incomingReportId && id != Guid.Empty)
            .Distinct()
            .ToList();

        if (otherCandidateIds.Count == 0) return;

        var reportsToLink = await _context.Reports
            .Where(r => otherCandidateIds.Contains(r.ReportId) && r.ProblemId == null)
            .ToListAsync(cancellationToken);

        foreach (var r in reportsToLink)
        {
            r.ProblemId = problemId;
            r.UpdatedAt = DateTime.UtcNow;
            _logger.LogInformation("Consolidation linked unassigned related Report {ReportId} to Problem {ProblemId}", r.ReportId, problemId);
        }
    }

    private async Task<WorkflowRun?> RecordWorkflowEventAsync(
        Guid? workflowRunId,
        Guid reportId,
        ProblemConsolidationResultDto consolidationResult,
        ConsolidationOutcomeDto outcome,
        CancellationToken cancellationToken,
        Guid? targetProblemId = null)
    {
        WorkflowRun? run = null;

        if (workflowRunId.HasValue)
        {
            run = await _context.WorkflowRuns.FindAsync(new object[] { workflowRunId.Value }, cancellationToken);
        }

        if (run == null)
        {
            run = await _context.WorkflowRuns
                .Where(w => w.ReportId == reportId && w.Status == "RUNNING")
                .OrderByDescending(w => w.CreatedAt)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (run != null)
        {
            var isSuccess = outcome.ValidationStatus == "PASSED";
            var status = isSuccess ? "COMPLETED" : (outcome.ValidationStatus == "SAFE_FAILURE" ? "SAFE_FAILURE" : "FAILED");

            var workflowEvent = new WorkflowEvent
            {
                WorkflowEventId = Guid.NewGuid(),
                WorkflowRunId = run.WorkflowRunId,
                AgentName = "ProblemConsolidationAgent",
                Stage = "PROBLEM_CONSOLIDATION",
                Status = status,
                InputData = JsonSerializer.Serialize(new { reportId = reportId }),
                OutputData = JsonSerializer.Serialize(new
                {
                    decision = consolidationResult.Decision,
                    problemId = targetProblemId,
                    summary = consolidationResult.Summary,
                    evidence = consolidationResult.Evidence
                }),
                ValidationResult = outcome.ValidationStatus,
                StartedAt = DateTime.UtcNow,
                CompletedAt = DateTime.UtcNow,
                ErrorMessage = outcome.ValidationErrors.Count > 0 ? string.Join("; ", outcome.ValidationErrors) : null
            };

            _context.WorkflowEvents.Add(workflowEvent);
        }

        return run;
    }
}
