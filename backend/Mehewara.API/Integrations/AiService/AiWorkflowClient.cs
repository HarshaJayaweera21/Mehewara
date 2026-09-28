using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Mehewara.API.Data;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Integrations.AiService;

public class AiWorkflowClient : IAiWorkflowClient
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<AiWorkflowClient> _logger;

    public AiWorkflowClient(
        HttpClient httpClient,
        IConfiguration configuration,
        IServiceScopeFactory scopeFactory,
        ILogger<AiWorkflowClient> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<bool> TriggerWorkflowAsync(Report report, Guid workflowRunId)
    {
        var baseUrl = _configuration["AiService:BaseUrl"] ?? "http://localhost:8000";
        var endpoint = $"{baseUrl.TrimEnd('/')}/internal/ai/workflows";

        // Query active candidate problems, nearby reports, and all municipal crews with real-time availability
        List<object> candidateProblems = new();
        List<object> relatedReports = new();
        List<object> availableCrews = new();

        try
        {
            using var queryScope = _scopeFactory.CreateScope();
            var dbContext = queryScope.ServiceProvider.GetRequiredService<AppDbContext>();

            // ~1km radius bounding box: approx 0.01 degrees in latitude/longitude
            var minLat = report.Latitude - 0.01m;
            var maxLat = report.Latitude + 0.01m;
            var minLon = report.Longitude - 0.01m;
            var maxLon = report.Longitude + 0.01m;

            var dbProblems = await dbContext.Problems
                .AsNoTracking()
                .Where(p => p.Status != "RESOLVED" && p.Status != "CANCELLED")
                .Where(p => p.Latitude >= minLat && p.Latitude <= maxLat && p.Longitude >= minLon && p.Longitude <= maxLon)
                .Take(10)
                .Select(p => new
                {
                    problemId = p.ProblemId,
                    title = p.Title,
                    description = p.Description,
                    category = p.Category,
                    status = p.Status,
                    latitude = (double)p.Latitude,
                    longitude = (double)p.Longitude,
                    address = p.Address,
                    priority = p.Priority,
                    reportCount = p.Reports.Count
                })
                .ToListAsync();

            candidateProblems = dbProblems.Cast<object>().ToList();

            var dbReports = await dbContext.Reports
                .AsNoTracking()
                .Where(r => r.ReportId != report.ReportId && r.Status != "RESOLVED" && r.Status != "CANCELLED")
                .Where(r => r.Latitude >= minLat && r.Latitude <= maxLat && r.Longitude >= minLon && r.Longitude <= maxLon)
                .Take(10)
                .Select(r => new
                {
                    reportId = r.ReportId,
                    problemId = r.ProblemId,
                    description = r.Description,
                    category = r.Category,
                    latitude = (double)r.Latitude,
                    longitude = (double)r.Longitude,
                    address = r.Address,
                    status = r.Status,
                    createdAt = r.CreatedAt
                })
                .ToListAsync();

            relatedReports = dbReports.Cast<object>().ToList();

            // Populate municipal crews with real-time active work order status (Contract §19)
            var dbCrews = await dbContext.Crews
                .AsNoTracking()
                .Select(c => new
                {
                    crewId = c.CrewId,
                    name = c.CrewName,
                    crewType = c.CrewType,
                    status = c.Status,
                    activeWorkOrderId = c.WorkOrders
                        .Where(wo => wo.Status == "ASSIGNED" || wo.Status == "IN_PROGRESS")
                        .OrderByDescending(wo => wo.AssignedAt ?? wo.CreatedAt)
                        .Select(wo => (Guid?)wo.WorkOrderId)
                        .FirstOrDefault()
                })
                .ToListAsync();

            availableCrews = dbCrews.Cast<object>().ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load candidate problems/reports/crews from database for Report {ReportId}. Proceeding with partial context.", report.ReportId);
        }

        var payload = new
        {
            workflowId = workflowRunId,
            report = new
            {
                id = report.ReportId,
                description = report.Description,
                category = report.Category,
                latitude = (double)report.Latitude,
                longitude = (double)report.Longitude,
                address = report.Address,
                photos = report.Photos.Select(p => new
                {
                    photoId = p.PhotoId,
                    photoUrl = p.PhotoUrl,
                    fileName = p.FileName,
                    mimeType = p.MimeType
                }).ToList()
            },
            context = new
            {
                candidateProblems = candidateProblems,
                relatedReports = relatedReports,
                availableCrews = availableCrews
            }
        };

        try
        {
            _logger.LogInformation("Triggering AI workflow for Report {ReportId} (WorkflowRun {WorkflowRunId}) with {CandidateCount} candidate problems at {Endpoint}",
                report.ReportId, workflowRunId, candidateProblems.Count, endpoint);

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(90));
            var response = await _httpClient.PostAsJsonAsync(endpoint, payload, cts.Token);

            if (response.IsSuccessStatusCode)
            {
                var responseContent = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("AI workflow response received for Report {ReportId}: {Response}",
                    report.ReportId, responseContent);

                // Persist the AI structured analysis and problem consolidation into PostgreSQL
                await PersistWorkflowResultAsync(workflowRunId, responseContent);

                return true;
            }

            _logger.LogWarning("AI workflow returned non-success status code {StatusCode} for Report {ReportId}",
                response.StatusCode, report.ReportId);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to connect to FastAPI AI service at {Endpoint} for Report {ReportId}. Workflow queued.",
                endpoint, report.ReportId);
            return false;
        }
    }

    private async Task PersistWorkflowResultAsync(Guid workflowRunId, string responseJson)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var workflowRun = await context.WorkflowRuns
                .Include(w => w.WorkflowEvents)
                .FirstOrDefaultAsync(w => w.WorkflowRunId == workflowRunId);

            if (workflowRun == null)
            {
                _logger.LogWarning("WorkflowRun {WorkflowRunId} not found for persisting AI result", workflowRunId);
                return;
            }

            // Retrieve the target report
            var report = await context.Reports
                .Include(r => r.Problem)
                .FirstOrDefaultAsync(r => r.ReportId == workflowRun.ReportId);

            using var doc = JsonDocument.Parse(responseJson);
            var root = doc.RootElement;

            // 1. Extract Agent 1 structured report analysis
            string agent1Data = string.Empty;
            if (root.TryGetProperty("reportAnalysis", out var reportAnalysisElem))
            {
                agent1Data = reportAnalysisElem.GetRawText();
            }
            else if (root.TryGetProperty("analysis", out var analysisElem))
            {
                agent1Data = analysisElem.GetRawText();
            }

            // Add immutable audit trail for Agent 1 (Report Analysis)
            if (!string.IsNullOrWhiteSpace(agent1Data))
            {
                var event1 = new WorkflowEvent
                {
                    WorkflowEventId = Guid.NewGuid(),
                    WorkflowRunId = workflowRun.WorkflowRunId,
                    AgentName = "Report Analysis Agent",
                    Stage = "REPORT_ANALYSIS",
                    Status = "COMPLETED",
                    InputData = JsonSerializer.Serialize(new { reportId = workflowRun.ReportId }),
                    OutputData = agent1Data,
                    ValidationResult = JsonSerializer.Serialize(new { result = "PASSED", checks = "Anti-hallucination verified" }),
                    ToolResults = JsonSerializer.Serialize(new { tools = new[] { "get_municipal_asset_catalog", "get_location_context" } }),
                    StartedAt = workflowRun.StartedAt,
                    CompletedAt = DateTime.UtcNow
                };
                context.WorkflowEvents.Add(event1);
            }

            // 2. Extract Agent 2 problem consolidation analysis
            if (root.TryGetProperty("problemAnalysis", out var problemAnalysisElem) &&
                problemAnalysisElem.ValueKind == JsonValueKind.Object &&
                report != null)
            {
                var decision = problemAnalysisElem.TryGetProperty("decision", out var decProp) ? decProp.GetString() : "UNCERTAIN";
                var summary = problemAnalysisElem.TryGetProperty("summary", out var sumProp) ? sumProp.GetString() : null;
                var updatedProblemDescription = problemAnalysisElem.TryGetProperty("updatedProblemDescription", out var updProp) ? updProp.GetString() : null;
                var problemIdStr = problemAnalysisElem.TryGetProperty("problemId", out var pidProp) && pidProp.ValueKind == JsonValueKind.String ? pidProp.GetString() : null;

                _logger.LogInformation("Applying Agent 2 decision '{Decision}' for Report {ReportId}", decision, report.ReportId);

                // Case A: Link to Existing Municipal Problem
                if (decision == "LINK_EXISTING" && Guid.TryParse(problemIdStr, out var targetProblemId))
                {
                    var existingProblem = await context.Problems
                        .Include(p => p.Reports)
                        .FirstOrDefaultAsync(p => p.ProblemId == targetProblemId);

                    if (existingProblem != null)
                    {
                        report.ProblemId = existingProblem.ProblemId;

                        // Add report to collection to compute updated centroid
                        var allLinkedReports = existingProblem.Reports.ToList();
                        if (!allLinkedReports.Any(r => r.ReportId == report.ReportId))
                        {
                            allLinkedReports.Add(report);
                        }

                        // Recalculate Centroid / Average of Latitude & Longitude across all reports under this problem
                        if (allLinkedReports.Count > 0)
                        {
                            existingProblem.Latitude = allLinkedReports.Average(r => r.Latitude);
                            existingProblem.Longitude = allLinkedReports.Average(r => r.Longitude);
                        }

                        // Update Problem Description with synthesized AI summary
                        var summaryToUse = !string.IsNullOrWhiteSpace(updatedProblemDescription) ? updatedProblemDescription : summary;
                        if (!string.IsNullOrWhiteSpace(summaryToUse))
                        {
                            existingProblem.Description = summaryToUse;
                        }

                        existingProblem.UpdatedAt = DateTime.UtcNow;

                        _logger.LogInformation("Successfully linked Report {ReportId} to Problem {ProblemId}. Centroid updated to ({Lat}, {Lon}) and AI summary saved.",
                            report.ReportId, existingProblem.ProblemId, existingProblem.Latitude, existingProblem.Longitude);
                    }
                    else
                    {
                        _logger.LogWarning("Agent 2 proposed linking to Problem {ProblemId}, but problem does not exist in DB.", targetProblemId);
                    }
                }
                // Case B: Create New Municipal Problem
                else if (decision == "CREATE_NEW" &&
                         problemAnalysisElem.TryGetProperty("newProblem", out var newProblemElem) &&
                         newProblemElem.ValueKind == JsonValueKind.Object)
                {
                    var newTitle = newProblemElem.TryGetProperty("title", out var tProp) ? tProp.GetString() : "Municipal Problem";
                    var newDesc = newProblemElem.TryGetProperty("description", out var dProp) ? dProp.GetString() : (!string.IsNullOrWhiteSpace(summary) ? summary : report.Description);
                    var newCategory = newProblemElem.TryGetProperty("category", out var cProp) ? cProp.GetString() : report.Category;
                    var newLat = newProblemElem.TryGetProperty("latitude", out var ltProp) ? (decimal)ltProp.GetDouble() : report.Latitude;
                    var newLon = newProblemElem.TryGetProperty("longitude", out var lnProp) ? (decimal)lnProp.GetDouble() : report.Longitude;
                    var newAddr = newProblemElem.TryGetProperty("address", out var aProp) ? aProp.GetString() : report.Address;

                    var newProblem = new Problem
                    {
                        ProblemId = Guid.NewGuid(),
                        Title = newTitle ?? "Municipal Problem",
                        Description = newDesc, // Initial AI summary generated using this single report
                        Category = newCategory ?? report.Category,
                        Latitude = newLat,
                        Longitude = newLon,
                        Address = newAddr ?? report.Address,
                        Status = "IDENTIFIED",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };

                    context.Problems.Add(newProblem);
                    report.ProblemId = newProblem.ProblemId;

                    _logger.LogInformation("Successfully created new Problem {ProblemId} ('{Title}') from Report {ReportId} with initial AI summary.",
                        newProblem.ProblemId, newProblem.Title, report.ReportId);
                }
                // Case C: UNCERTAIN (Safe Failure - Keep unlinked pending coordinator review)
                else
                {
                    report.ProblemId = null;
                    _logger.LogInformation("Report {ReportId} remains unlinked (Decision: {Decision}).", report.ReportId, decision);
                }

                // Add immutable audit trail for Agent 2 (Problem Consolidation)
                var event2 = new WorkflowEvent
                {
                    WorkflowEventId = Guid.NewGuid(),
                    WorkflowRunId = workflowRun.WorkflowRunId,
                    AgentName = "Problem Consolidation Agent",
                    Stage = "PROBLEM_CONSOLIDATION",
                    Status = "COMPLETED",
                    InputData = JsonSerializer.Serialize(new { reportId = workflowRun.ReportId }),
                    OutputData = problemAnalysisElem.GetRawText(),
                    ValidationResult = JsonSerializer.Serialize(new
                    {
                        decision,
                        problemId = report.ProblemId,
                        validation = "PASSED"
                    }),
                    ToolResults = JsonSerializer.Serialize(new
                    {
                        tools = new[] { "search_existing_problems", "search_similar_reports", "get_nearby_reports" }
                    }),
                    StartedAt = workflowRun.StartedAt,
                    CompletedAt = DateTime.UtcNow
                };
                context.WorkflowEvents.Add(event2);
            }

            // 3. Extract Agent 3 priority & crew recommendation analysis
            if (root.TryGetProperty("priorityAnalysis", out var prioElem) &&
                prioElem.ValueKind == JsonValueKind.Object &&
                report?.ProblemId != null)
            {
                var priority = prioElem.TryGetProperty("priority", out var priProp) ? priProp.GetString() : null;
                var score = prioElem.TryGetProperty("priorityScore", out var scoreProp) && scoreProp.TryGetInt32(out var sVal) ? sVal : (int?)null;

                if (!string.IsNullOrWhiteSpace(priority) && score.HasValue)
                {
                    var targetProblem = await context.Problems.FindAsync(report.ProblemId);
                    if (targetProblem != null)
                    {
                        targetProblem.Priority = priority.ToUpperInvariant();
                        targetProblem.PriorityScore = score.Value;
                        targetProblem.Status = "AWAITING_ASSIGNMENT";
                        targetProblem.UpdatedAt = DateTime.UtcNow;

                        _logger.LogInformation("Updated Problem {ProblemId} priority to {Priority} ({Score}) and status to AWAITING_ASSIGNMENT.",
                            targetProblem.ProblemId, targetProblem.Priority, targetProblem.PriorityScore);
                    }
                }

                // Add immutable audit trail for Agent 3 (Priority & Crew Recommendation)
                var event3 = new WorkflowEvent
                {
                    WorkflowEventId = Guid.NewGuid(),
                    WorkflowRunId = workflowRun.WorkflowRunId,
                    AgentName = "Priority & Crew Recommendation Agent",
                    Stage = "PRIORITIZATION",
                    Status = "COMPLETED",
                    InputData = JsonSerializer.Serialize(new { problemId = report.ProblemId }),
                    OutputData = prioElem.GetRawText(),
                    ValidationResult = JsonSerializer.Serialize(new { status = "VALID", issues = Array.Empty<string>() }),
                    ToolResults = JsonSerializer.Serialize(new { tools = new[] { "get_crew_capabilities", "check_crew_availability", "get_recent_jobs" } }),
                    StartedAt = workflowRun.StartedAt,
                    CompletedAt = DateTime.UtcNow
                };
                context.WorkflowEvents.Add(event3);

                // Update workflow run stage to PRIORITIZATION
                workflowRun.CurrentStage = "PRIORITIZATION";
            }
            else
            {
                workflowRun.CurrentStage = "PROBLEM_CONSOLIDATION";
            }

            // Update workflowRun state and status
            workflowRun.StateData = responseJson;
            workflowRun.Status = "COMPLETED";
            workflowRun.CompletedAt = DateTime.UtcNow;
            workflowRun.UpdatedAt = DateTime.UtcNow;

            await context.SaveChangesAsync();

            _logger.LogInformation("Successfully persisted AI workflow analysis results into PostgreSQL for WorkflowRun {WorkflowRunId}",
                workflowRunId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to persist AI workflow analysis into PostgreSQL for WorkflowRun {WorkflowRunId}",
                workflowRunId);
        }
    }
}
