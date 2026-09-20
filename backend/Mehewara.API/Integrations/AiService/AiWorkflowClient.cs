using System.Net.Http.Json;
using System.Text.Json;
using Mehewara.API.Models;

namespace Mehewara.API.Integrations.AiService;

public class AiWorkflowClient : IAiWorkflowClient
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AiWorkflowClient> _logger;

    public AiWorkflowClient(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<AiWorkflowClient> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<bool> TriggerWorkflowAsync(Report report, Guid workflowRunId)
    {
        var baseUrl = _configuration["AiService:BaseUrl"] ?? "http://localhost:8000";
        var endpoint = $"{baseUrl.TrimEnd('/')}/internal/ai/workflows";

        var payload = new
        {
            workflowId = workflowRunId,
            report = new
            {
                id = report.ReportId,
                description = report.Description,
                category = report.Category,
                latitude = report.Latitude,
                longitude = report.Longitude,
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
                candidateProblems = new List<object>(),
                relatedReports = new List<object>(),
                availableCrews = new List<object>()
            }
        };

        try
        {
            _logger.LogInformation("Triggering AI workflow for Report {ReportId} (WorkflowRun {WorkflowRunId}) at {Endpoint}",
                report.ReportId, workflowRunId, endpoint);

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            var response = await _httpClient.PostAsJsonAsync(endpoint, payload, cts.Token);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("AI workflow initiated successfully for Report {ReportId}", report.ReportId);
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
}
