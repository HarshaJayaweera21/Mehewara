using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Reports;
using Mehewara.API.Exceptions;
using Mehewara.API.Integrations.AiService;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class ReportService : IReportService
{
    private static readonly HashSet<string> AllowedCategories = new(StringComparer.OrdinalIgnoreCase)
    {
        "DRAINAGE", "ROAD", "WASTE", "ELECTRICAL", "ENVIRONMENT"
    };

    private static readonly HashSet<string> AllowedStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "PENDING", "PROCESSING", "ASSIGNED", "RESOLVED", "CANCELLED"
    };

    private readonly AppDbContext _context;
    private readonly IPhotoStorageService _photoStorageService;
    private readonly IAiWorkflowClient _aiWorkflowClient;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ReportService> _logger;

    public ReportService(
        AppDbContext context,
        IPhotoStorageService photoStorageService,
        IAiWorkflowClient aiWorkflowClient,
        IServiceScopeFactory scopeFactory,
        ILogger<ReportService> logger)
    {
        _context = context;
        _photoStorageService = photoStorageService;
        _aiWorkflowClient = aiWorkflowClient;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<ReportResponse> CreateReportAsync(Guid residentId, CreateReportRequest request)
    {
        var category = request.Category.Trim().ToUpperInvariant();
        if (!AllowedCategories.Contains(category))
        {
            throw new ValidationException($"Invalid category '{request.Category}'. Allowed categories are: {string.Join(", ", AllowedCategories)}");
        }

        if (request.Latitude < -90m || request.Latitude > 90m)
        {
            throw new ValidationException("Latitude must be between -90 and 90 degrees.");
        }

        if (request.Longitude < -180m || request.Longitude > 180m)
        {
            throw new ValidationException("Longitude must be between -180 and 180 degrees.");
        }

        var resident = await _context.Users.FindAsync(residentId);
        if (resident == null)
        {
            throw new NotFoundException("Resident user not found.");
        }

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = residentId,
            Description = request.Description.Trim(),
            Category = category,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Address = string.IsNullOrWhiteSpace(request.Address) ? null : request.Address.Trim(),
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Resident = resident
        };

        if (request.Photos != null && request.Photos.Count > 0)
        {
            foreach (var photoReq in request.Photos)
            {
                if (string.IsNullOrWhiteSpace(photoReq.PhotoUrl)) continue;

                report.Photos.Add(new ReportPhoto
                {
                    PhotoId = Guid.NewGuid(),
                    ReportId = report.ReportId,
                    PhotoUrl = photoReq.PhotoUrl.Trim(),
                    FileName = string.IsNullOrWhiteSpace(photoReq.FileName) ? null : photoReq.FileName.Trim(),
                    MimeType = string.IsNullOrWhiteSpace(photoReq.MimeType) ? null : photoReq.MimeType.Trim(),
                    UploadedAt = DateTime.UtcNow
                });
            }
        }

        var workflowRun = new WorkflowRun
        {
            WorkflowRunId = Guid.NewGuid(),
            ReportId = report.ReportId,
            CurrentStage = "REPORT_ANALYSIS",
            Status = "RUNNING",
            StartedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        report.WorkflowRuns.Add(workflowRun);
        _context.Reports.Add(report);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Report {ReportId} created successfully for resident {ResidentId} with status PENDING",
            report.ReportId, residentId);

        // Initiate AI workflow push trigger in a safe background scope
        var createdReportId = report.ReportId;
        var createdWorkflowId = workflowRun.WorkflowRunId;

        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var scopedContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var scopedAiClient = scope.ServiceProvider.GetRequiredService<IAiWorkflowClient>();

                var scopedReport = await scopedContext.Reports
                    .Include(r => r.Photos)
                    .FirstOrDefaultAsync(r => r.ReportId == createdReportId);

                if (scopedReport != null)
                {
                    var triggered = await scopedAiClient.TriggerWorkflowAsync(scopedReport, createdWorkflowId);
                    if (triggered)
                    {
                        scopedReport.Status = "PROCESSING";
                        scopedReport.UpdatedAt = DateTime.UtcNow;
                        await scopedContext.SaveChangesAsync();
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Background trigger of AI workflow for Report {ReportId} logged error", createdReportId);
            }
        });

        return MapToReportResponse(report);
    }

    public async Task<PagedResult<ReportSummaryResponse>> GetReportsAsync(ReportFilterRequest filter)
    {
        var page = filter.Page > 0 ? filter.Page : 1;
        var pageSize = filter.PageSize > 0 && filter.PageSize <= 100 ? filter.PageSize : 20;

        var query = _context.Reports
            .Include(r => r.Photos)
            .Include(r => r.Problem)
            .AsNoTracking();

        if (!string.IsNullOrWhiteSpace(filter.Status))
        {
            var status = filter.Status.Trim().ToUpperInvariant();
            query = query.Where(r => r.Status == status);
        }

        if (!string.IsNullOrWhiteSpace(filter.Category))
        {
            var category = filter.Category.Trim().ToUpperInvariant();
            query = query.Where(r => r.Category == category);
        }

        if (filter.FromDate.HasValue)
        {
            query = query.Where(r => r.CreatedAt >= filter.FromDate.Value.ToUniversalTime());
        }

        if (filter.ToDate.HasValue)
        {
            query = query.Where(r => r.CreatedAt <= filter.ToDate.Value.ToUniversalTime());
        }

        if (!string.IsNullOrWhiteSpace(filter.Search))
        {
            var search = filter.Search.Trim().ToLower();
            query = query.Where(r => r.Description.ToLower().Contains(search) ||
                                     (r.Address != null && r.Address.ToLower().Contains(search)));
        }

        var isAscending = string.Equals(filter.SortDirection, "asc", StringComparison.OrdinalIgnoreCase);
        var sortBy = filter.SortBy?.Trim().ToLowerInvariant() ?? "createdat";

        query = sortBy switch
        {
            "category" => isAscending ? query.OrderBy(r => r.Category) : query.OrderByDescending(r => r.Category),
            "status" => isAscending ? query.OrderBy(r => r.Status) : query.OrderByDescending(r => r.Status),
            _ => isAscending ? query.OrderBy(r => r.CreatedAt) : query.OrderByDescending(r => r.CreatedAt)
        };

        var totalItems = await query.CountAsync();

        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(r => new ReportSummaryResponse
            {
                Id = r.ReportId,
                Description = r.Description,
                Category = r.Category,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                Address = r.Address,
                Status = r.Status,
                LinkedProblemCount = r.ProblemId.HasValue ? 1 : 0,
                FirstPhotoUrl = r.Photos.OrderBy(p => p.UploadedAt).Select(p => p.PhotoUrl).FirstOrDefault(),
                CreatedAt = r.CreatedAt
            })
            .ToListAsync();

        return new PagedResult<ReportSummaryResponse>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            SortBy = sortBy,
            SortDirection = isAscending ? "asc" : "desc"
        };
    }

    public async Task<ReportResponse> GetReportByIdAsync(Guid reportId, Guid userId, string userRole)
    {
        var report = await _context.Reports
            .Include(r => r.Resident)
            .Include(r => r.Photos)
            .Include(r => r.Problem)
            .Include(r => r.WorkflowRuns)
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.ReportId == reportId);

        if (report == null)
        {
            throw new NotFoundException($"Report with ID {reportId} was not found.");
        }

        var isAdmin = string.Equals(userRole, "ADMIN", StringComparison.OrdinalIgnoreCase);
        if (!isAdmin && report.ResidentId != userId)
        {
            throw new ForbiddenException("You are not authorized to view this report.");
        }

        return MapToReportResponse(report);
    }

    public async Task<PagedResult<ReportSummaryResponse>> GetResidentReportsAsync(
        Guid residentId,
        int page,
        int pageSize,
        string? status,
        string? sortBy,
        string? sortDirection)
    {
        page = page > 0 ? page : 1;
        pageSize = pageSize > 0 && pageSize <= 100 ? pageSize : 20;

        var query = _context.Reports
            .Include(r => r.Photos)
            .Include(r => r.Problem)
            .Where(r => r.ResidentId == residentId)
            .AsNoTracking();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var st = status.Trim().ToUpperInvariant();
            query = query.Where(r => r.Status == st);
        }

        var isAscending = string.Equals(sortDirection, "asc", StringComparison.OrdinalIgnoreCase);
        var sortCol = sortBy?.Trim().ToLowerInvariant() ?? "createdat";

        query = sortCol switch
        {
            "category" => isAscending ? query.OrderBy(r => r.Category) : query.OrderByDescending(r => r.Category),
            "status" => isAscending ? query.OrderBy(r => r.Status) : query.OrderByDescending(r => r.Status),
            _ => isAscending ? query.OrderBy(r => r.CreatedAt) : query.OrderByDescending(r => r.CreatedAt)
        };

        var totalItems = await query.CountAsync();

        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(r => new ReportSummaryResponse
            {
                Id = r.ReportId,
                Description = r.Description,
                Category = r.Category,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                Address = r.Address,
                Status = r.Status,
                LinkedProblemCount = r.ProblemId.HasValue ? 1 : 0,
                FirstPhotoUrl = r.Photos.OrderBy(p => p.UploadedAt).Select(p => p.PhotoUrl).FirstOrDefault(),
                CreatedAt = r.CreatedAt
            })
            .ToListAsync();

        return new PagedResult<ReportSummaryResponse>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            SortBy = sortCol,
            SortDirection = isAscending ? "asc" : "desc"
        };
    }

    public async Task<ReportPhotoDto> UploadReportPhotoAsync(IFormFile file)
    {
        var (secureUrl, _) = await _photoStorageService.UploadPhotoAsync(file, "mehewara/reports");

        return new ReportPhotoDto
        {
            PhotoId = Guid.NewGuid(),
            PhotoUrl = secureUrl,
            FileName = Path.GetFileName(file.FileName),
            MimeType = file.ContentType,
            UploadedAt = DateTime.UtcNow
        };
    }

    private static ReportResponse MapToReportResponse(Report report)
    {
        var response = new ReportResponse
        {
            Id = report.ReportId,
            ResidentId = report.ResidentId,
            ResidentName = report.Resident != null ? $"{report.Resident.FirstName} {report.Resident.LastName}".Trim() : null,
            ResidentEmail = report.Resident?.Email,
            Description = report.Description,
            Category = report.Category,
            Latitude = report.Latitude,
            Longitude = report.Longitude,
            Address = report.Address,
            Status = report.Status,
            AiAnalysis = report.WorkflowRuns?.OrderByDescending(w => w.CreatedAt).FirstOrDefault()?.StateData,
            CreatedAt = report.CreatedAt,
            UpdatedAt = report.UpdatedAt,
            Photos = report.Photos.Select(p => new ReportPhotoDto
            {
                PhotoId = p.PhotoId,
                PhotoUrl = p.PhotoUrl,
                FileName = p.FileName,
                MimeType = p.MimeType,
                UploadedAt = p.UploadedAt
            }).ToList()
        };

        if (report.Problem != null)
        {
            response.LinkedProblems.Add(new LinkedProblemDto
            {
                ProblemId = report.Problem.ProblemId,
                Title = report.Problem.Title,
                Category = report.Problem.Category,
                Priority = report.Problem.Priority,
                WorkStatus = report.Problem.Status,
                LinkedAt = report.UpdatedAt
            });
        }

        return response;
    }
}
