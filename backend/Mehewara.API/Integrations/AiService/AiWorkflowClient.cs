using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Mehewara.API.Data;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Integrations.AiService;

public class AiWorkflowClient : IAiWorkflowClient
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ICrewLocationService _crewLocationService;
    private readonly ILogger<AiWorkflowClient> _logger;

    public AiWorkflowClient(
        HttpClient httpClient,
        IConfiguration configuration,
        IServiceScopeFactory scopeFactory,
        ICrewLocationService crewLocationService,
        ILogger<AiWorkflowClient> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _scopeFactory = scopeFactory;
        _crewLocationService = crewLocationService;
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
        var contextComplete = true;

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

            availableCrews = dbCrews.Select(c =>
            {
                var loc = _crewLocationService.GetCurrentLocation(c.crewId);
                return (object)new
                {
                    crewId = c.crewId,
                    name = c.name,
                    crewType = c.crewType,
                    status = c.status,
                    activeWorkOrderId = c.activeWorkOrderId,
                    latitude = (double)loc.Latitude,
                    longitude = (double)loc.Longitude
                };
            }).ToList();
        }
        catch (Exception ex)
        {
            contextComplete = false;
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
                    fileName = p.FileName ?? "attachment",
                    mimeType = p.MimeType ?? "application/octet-stream"
                }).ToList()
            },
            context = new
            {
                complete = contextComplete,
                candidateProblems = candidateProblems,
                relatedReports = relatedReports,
                availableCrews = availableCrews
            }
        };

        using (var snapshotScope = _scopeFactory.CreateScope())
        {
            var snapshotDb = snapshotScope.ServiceProvider.GetRequiredService<AppDbContext>();
            var snapshotRun = await snapshotDb.WorkflowRuns.SingleAsync(w => w.WorkflowRunId == workflowRunId);
            snapshotRun.InputData = JsonSerializer.Serialize(payload);
            await snapshotDb.SaveChangesAsync();
        }

        try
        {
            _logger.LogInformation("Triggering AI workflow for Report {ReportId} (WorkflowRun {WorkflowRunId}) with {CandidateCount} candidate problems at {Endpoint}",
                report.ReportId, workflowRunId, candidateProblems.Count, endpoint);

            using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(5));
            using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
            var key = _configuration["AiService:InternalApiKey"];
            if (string.IsNullOrWhiteSpace(key)) throw new InvalidOperationException("Internal AI key is not configured.");
            request.Headers.Add("X-Internal-Api-Key", key);
            request.Content = JsonContent.Create(payload);
            using var response = await _httpClient.SendAsync(request, cts.Token);

            if (response.IsSuccessStatusCode)
            {
                var responseContent = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("AI workflow response received for Report {ReportId}", report.ReportId);

                // Persist the AI structured analysis and problem consolidation into PostgreSQL
                await PersistWorkflowResultAsync(workflowRunId, responseContent);

                return true;
            }

            _logger.LogWarning("AI workflow returned non-success status code {StatusCode} for Report {ReportId}",
                response.StatusCode, report.ReportId);
            using var failureScope = _scopeFactory.CreateScope();
            await failureScope.ServiceProvider.GetRequiredService<Mehewara.API.Services.Implementations.AiReviewService>().MarkInitialFailureAsync(workflowRunId);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to connect to FastAPI AI service at {Endpoint} for Report {ReportId}. Workflow failed.",
                endpoint, report.ReportId);
            using var failureScope = _scopeFactory.CreateScope();
            await failureScope.ServiceProvider.GetRequiredService<Mehewara.API.Services.Implementations.AiReviewService>().MarkInitialFailureAsync(workflowRunId);
            return false;
        }
    }

    private async Task PersistWorkflowResultAsync(Guid workflowRunId, string responseJson)
    {
        using var scope = _scopeFactory.CreateScope();
        await scope.ServiceProvider.GetRequiredService<Mehewara.API.Services.Implementations.AiReviewService>()
            .PersistInitialAsync(workflowRunId, responseJson);
    }
}
