using Mehewara.API.Common;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems;
using Mehewara.API.DTOs.Problems.Consolidation;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class ProblemService : IProblemService
{
    private readonly AppDbContext _context;

    public ProblemService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ProblemResponse> CreateProblemAsync(
        CreateProblemRequest request)
    {
        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = request.Title,
            Description = request.Description,
            Category = request.Category,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Address = request.Address,

            Status = "IDENTIFIED",

            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Problems.Add(problem);

        await _context.SaveChangesAsync();

        return new ProblemResponse
        {
            Id = problem.ProblemId,
            Title = problem.Title,
            Description = problem.Description,
            Category = problem.Category,
            Latitude = problem.Latitude,
            Longitude = problem.Longitude,
            Address = problem.Address,
            Priority = problem.Priority,
            PriorityScore = problem.PriorityScore,
            Status = problem.Status,
            RelatedReportCount = 0,
            CreatedAt = problem.CreatedAt,
            UpdatedAt = problem.UpdatedAt
        };
    }

    public async Task<PagedResult<ProblemResponse>> GetProblemsAsync(GetProblemsQuery query)
    {
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = query.PageSize < 1 ? 20 : (query.PageSize > 100 ? 100 : query.PageSize);

        var queryable = _context.Problems.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Category))
        {
            var normalizedCategory = query.Category.Trim().ToUpperInvariant();
            queryable = queryable.Where(p => p.Category == normalizedCategory);
        }

        if (!string.IsNullOrWhiteSpace(query.Priority))
        {
            var normalizedPriority = query.Priority.Trim().ToUpperInvariant();
            queryable = queryable.Where(p => p.Priority == normalizedPriority);
        }

        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            var normalizedStatus = query.Status.Trim().ToUpperInvariant();
            queryable = queryable.Where(p => p.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var searchTerm = query.Search.Trim().ToLower();
            queryable = queryable.Where(p =>
                p.Title.ToLower().Contains(searchTerm) ||
                (p.Description != null && p.Description.ToLower().Contains(searchTerm)) ||
                (p.Address != null && p.Address.ToLower().Contains(searchTerm)));
        }

        if (query.FromDate.HasValue)
        {
            queryable = queryable.Where(p => p.CreatedAt >= query.FromDate.Value);
        }

        if (query.ToDate.HasValue)
        {
            queryable = queryable.Where(p => p.CreatedAt <= query.ToDate.Value);
        }

        var totalItems = await queryable.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

        var sortDirection = (query.SortDirection ?? "desc").Trim().ToLowerInvariant();
        var isAscending = sortDirection == "asc";
        var sortBy = (query.SortBy ?? "createdAt").Trim().ToLowerInvariant();

        queryable = sortBy switch
        {
            "title" => isAscending ? queryable.OrderBy(p => p.Title) : queryable.OrderByDescending(p => p.Title),
            "category" => isAscending ? queryable.OrderBy(p => p.Category) : queryable.OrderByDescending(p => p.Category),
            "priority" => isAscending ? queryable.OrderBy(p => p.Priority) : queryable.OrderByDescending(p => p.Priority),
            "priorityscore" => isAscending ? queryable.OrderBy(p => p.PriorityScore) : queryable.OrderByDescending(p => p.PriorityScore),
            "status" => isAscending ? queryable.OrderBy(p => p.Status) : queryable.OrderByDescending(p => p.Status),
            _ => isAscending ? queryable.OrderBy(p => p.CreatedAt) : queryable.OrderByDescending(p => p.CreatedAt)
        };

        var items = await queryable
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(p => new ProblemResponse
            {
                Id = p.ProblemId,
                Title = p.Title,
                Description = p.Description,
                Category = p.Category,
                Latitude = p.Latitude,
                Longitude = p.Longitude,
                Address = p.Address,
                Priority = p.Priority,
                PriorityScore = p.PriorityScore,
                Status = p.Status,
                RelatedReportCount = p.Reports.Count,
                CreatedAt = p.CreatedAt,
                UpdatedAt = p.UpdatedAt
            })
            .ToListAsync();

        return new PagedResult<ProblemResponse>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            TotalPages = totalPages,
            SortBy = sortBy,
            SortDirection = sortDirection
        };
    }

    public async Task<ProblemDetailResponse> GetProblemByIdAsync(Guid id)
    {
        var problem = await _context.Problems
            .AsNoTracking()
            .Where(p => p.ProblemId == id)
            .Select(p => new ProblemDetailResponse
            {
                Id = p.ProblemId,
                Title = p.Title,
                Description = p.Description,
                Category = p.Category,
                Latitude = p.Latitude,
                Longitude = p.Longitude,
                Address = p.Address,
                Priority = p.Priority,
                PriorityScore = p.PriorityScore,
                Status = p.Status,
                RelatedReports = p.Reports
                    .OrderByDescending(r => r.CreatedAt)
                    .Select(r => new RelatedReportSummary
                    {
                        ReportId = r.ReportId,
                        Description = r.Description,
                        Category = r.Category,
                        Status = r.Status,
                        Address = r.Address,
                        Latitude = r.Latitude,
                        Longitude = r.Longitude,
                        CreatedAt = r.CreatedAt
                    })
                    .ToList(),
                CreatedAt = p.CreatedAt,
                UpdatedAt = p.UpdatedAt
            })
            .FirstOrDefaultAsync();

        if (problem == null)
        {
            throw new NotFoundException($"Problem with ID '{id}' was not found.", "PROBLEM_NOT_FOUND");
        }

        return problem;
    }

    public async Task<IEnumerable<ProblemReportResponse>> GetReportsByProblemIdAsync(Guid problemId)
    {
        var problemExists = await _context.Problems
            .AnyAsync(p => p.ProblemId == problemId);

        if (!problemExists)
        {
            throw new NotFoundException($"Problem with ID '{problemId}' was not found.", "PROBLEM_NOT_FOUND");
        }

        var reports = await _context.Reports
            .AsNoTracking()
            .Where(r => r.ProblemId == problemId)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new ProblemReportResponse
            {
                Id = r.ReportId,
                ResidentId = r.ResidentId,
                ResidentName = r.Resident.FirstName + " " + r.Resident.LastName,
                Description = r.Description,
                Category = r.Category,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                Address = r.Address,
                Status = r.Status,
                PhotoUrls = r.Photos.Select(p => p.PhotoUrl).ToList(),
                CreatedAt = r.CreatedAt,
                UpdatedAt = r.UpdatedAt
            })
            .ToListAsync();

        return reports;
    }

    public async Task<List<UncertainReportResponse>> GetUncertainReportsAsync()
    {
        // 1. Fetch unassigned reports that need coordinator triage
        var reports = await _context.Reports
            .Include(r => r.Resident)
            .Include(r => r.Photos)
            .Include(r => r.WorkflowRuns)
                .ThenInclude(w => w.WorkflowEvents)
            .Where(r => r.ProblemId == null && r.Status != "RESOLVED" && r.Status != "CANCELLED")
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        if (reports.Count == 0)
        {
            return new List<UncertainReportResponse>();
        }

        // 2. Fetch active candidate problems to calculate proximity
        var activeProblems = await _context.Problems
            .AsNoTracking()
            .Include(p => p.Reports)
            .Where(p => p.Status != "RESOLVED" && p.Status != "CANCELLED")
            .ToListAsync();

        var result = new List<UncertainReportResponse>();

        foreach (var r in reports)
        {
            // Extract AI consolidation reason & evidence from WorkflowEvents if present
            string? uncertaintyReason = null;
            var evidenceList = new List<string>();

            var latestRun = r.WorkflowRuns.OrderByDescending(w => w.StartedAt).FirstOrDefault();
            if (latestRun != null)
            {
                var consolidationEvent = latestRun.WorkflowEvents
                    .Where(e => e.Stage == "PROBLEM_CONSOLIDATION")
                    .OrderByDescending(e => e.StartedAt)
                    .FirstOrDefault();

                if (consolidationEvent != null && !string.IsNullOrWhiteSpace(consolidationEvent.OutputData))
                {
                    try
                    {
                        using var doc = System.Text.Json.JsonDocument.Parse(consolidationEvent.OutputData);
                        if (doc.RootElement.TryGetProperty("summary", out var sumProp))
                        {
                            uncertaintyReason = sumProp.GetString();
                        }
                        if (doc.RootElement.TryGetProperty("evidence", out var evProp) && evProp.ValueKind == System.Text.Json.JsonValueKind.Array)
                        {
                            foreach (var item in evProp.EnumerateArray())
                            {
                                if (item.GetString() is { } str) evidenceList.Add(str);
                            }
                        }
                    }
                    catch
                    {
                        // Fallback gracefully if JSON parsing fails
                    }
                }
            }

            // Find closest active candidate problems (within 2km radius)
            var nearby = activeProblems
                .Select(p => new
                {
                    Problem = p,
                    Distance = CalculateDistanceMeters(r.Latitude, r.Longitude, p.Latitude, p.Longitude)
                })
                .Where(x => x.Distance <= 2000.0)
                .OrderBy(x => x.Distance)
                .Take(4)
                .Select(x => new NearbyCandidateProblemSummary
                {
                    ProblemId = x.Problem.ProblemId,
                    Title = x.Problem.Title,
                    Category = x.Problem.Category,
                    Address = x.Problem.Address,
                    DistanceMeters = x.Distance,
                    ReportCount = x.Problem.Reports.Count
                })
                .ToList();

            result.Add(new UncertainReportResponse
            {
                ReportId = r.ReportId,
                Description = r.Description,
                Category = r.Category,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                Address = r.Address,
                ResidentName = r.Resident != null ? $"{r.Resident.FirstName} {r.Resident.LastName}".Trim() : "Anonymous Citizen",
                CreatedAt = r.CreatedAt,
                PhotoUrls = r.Photos.Select(p => p.PhotoUrl).ToList(),
                AiUncertaintyReason = uncertaintyReason ?? "Flagged by AI Agent 2 for manual coordinator verification.",
                AiEvidence = evidenceList,
                NearbyCandidates = nearby
            });
        }

        return result;
    }

    public async Task<ProblemResponse> LinkUncertainReportAsync(LinkUncertainReportRequest request)
    {
        var report = await _context.Reports
            .FirstOrDefaultAsync(r => r.ReportId == request.ReportId);

        if (report == null)
        {
            throw new NotFoundException($"Report with ID '{request.ReportId}' was not found.", "REPORT_NOT_FOUND");
        }

        var problem = await _context.Problems
            .Include(p => p.Reports)
            .FirstOrDefaultAsync(p => p.ProblemId == request.ProblemId);

        if (problem == null)
        {
            throw new NotFoundException($"Problem with ID '{request.ProblemId}' was not found.", "PROBLEM_NOT_FOUND");
        }

        // 1. Link report
        report.ProblemId = problem.ProblemId;
        report.Status = "PROCESSING";
        report.UpdatedAt = DateTime.UtcNow;

        // 2. Add to problem's reports collection and recalculate Centroid coordinates
        var linkedReports = problem.Reports.ToList();
        if (!linkedReports.Any(r => r.ReportId == report.ReportId))
        {
            linkedReports.Add(report);
        }

        if (linkedReports.Count > 0)
        {
            problem.Latitude = linkedReports.Average(r => r.Latitude);
            problem.Longitude = linkedReports.Average(r => r.Longitude);
        }

        // 3. Append coordinator notes to description if provided
        if (!string.IsNullOrWhiteSpace(request.CoordinatorNotes))
        {
            problem.Description = string.IsNullOrWhiteSpace(problem.Description)
                ? request.CoordinatorNotes
                : $"{problem.Description}\n[Coordinator Note]: {request.CoordinatorNotes}";
        }

        problem.UpdatedAt = DateTime.UtcNow;

        // 4. Audit trail
        var auditEvent = new WorkflowEvent
        {
            WorkflowEventId = Guid.NewGuid(),
            WorkflowRunId = Guid.NewGuid(),
            AgentName = "Coordinator Manual Triage",
            Stage = "COORDINATOR_CONSOLIDATION_REVIEW",
            Status = "COMPLETED",
            InputData = System.Text.Json.JsonSerializer.Serialize(new { reportId = report.ReportId, problemId = problem.ProblemId }),
            OutputData = System.Text.Json.JsonSerializer.Serialize(new { action = "LINK_MANUAL", notes = request.CoordinatorNotes }),
            ValidationResult = System.Text.Json.JsonSerializer.Serialize(new { result = "PASSED", decision = "MANUAL_LINK" }),
            StartedAt = DateTime.UtcNow,
            CompletedAt = DateTime.UtcNow
        };
        _context.WorkflowEvents.Add(auditEvent);

        await _context.SaveChangesAsync();

        return new ProblemResponse
        {
            Id = problem.ProblemId,
            Title = problem.Title,
            Description = problem.Description,
            Category = problem.Category,
            Latitude = problem.Latitude,
            Longitude = problem.Longitude,
            Address = problem.Address,
            Priority = problem.Priority,
            PriorityScore = problem.PriorityScore,
            Status = problem.Status,
            RelatedReportCount = linkedReports.Count,
            CreatedAt = problem.CreatedAt,
            UpdatedAt = problem.UpdatedAt
        };
    }

    public async Task<ProblemResponse> CreateProblemFromUncertainReportAsync(CreateProblemFromUncertainReportRequest request)
    {
        var report = await _context.Reports
            .FirstOrDefaultAsync(r => r.ReportId == request.ReportId);

        if (report == null)
        {
            throw new NotFoundException($"Report with ID '{request.ReportId}' was not found.", "REPORT_NOT_FOUND");
        }

        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = request.Title,
            Description = request.Description ?? report.Description,
            Category = request.Category,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Address = request.Address ?? report.Address,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        if (!string.IsNullOrWhiteSpace(request.CoordinatorNotes))
        {
            problem.Description = $"{problem.Description}\n[Coordinator Note]: {request.CoordinatorNotes}";
        }

        _context.Problems.Add(problem);

        report.ProblemId = problem.ProblemId;
        report.Status = "PROCESSING";
        report.UpdatedAt = DateTime.UtcNow;

        // Audit trail
        var auditEvent = new WorkflowEvent
        {
            WorkflowEventId = Guid.NewGuid(),
            WorkflowRunId = Guid.NewGuid(),
            AgentName = "Coordinator Manual Triage",
            Stage = "COORDINATOR_CONSOLIDATION_REVIEW",
            Status = "COMPLETED",
            InputData = System.Text.Json.JsonSerializer.Serialize(new { reportId = report.ReportId }),
            OutputData = System.Text.Json.JsonSerializer.Serialize(new { action = "CREATE_MANUAL", problemId = problem.ProblemId, notes = request.CoordinatorNotes }),
            ValidationResult = System.Text.Json.JsonSerializer.Serialize(new { result = "PASSED", decision = "MANUAL_CREATE" }),
            StartedAt = DateTime.UtcNow,
            CompletedAt = DateTime.UtcNow
        };
        _context.WorkflowEvents.Add(auditEvent);

        await _context.SaveChangesAsync();

        return new ProblemResponse
        {
            Id = problem.ProblemId,
            Title = problem.Title,
            Description = problem.Description,
            Category = problem.Category,
            Latitude = problem.Latitude,
            Longitude = problem.Longitude,
            Address = problem.Address,
            Priority = problem.Priority,
            PriorityScore = problem.PriorityScore,
            Status = problem.Status,
            RelatedReportCount = 1,
            CreatedAt = problem.CreatedAt,
            UpdatedAt = problem.UpdatedAt
        };
    }

    private static double CalculateDistanceMeters(decimal lat1, decimal lon1, decimal lat2, decimal lon2)
    {
        const double R = 6371000; // Earth radius in meters
        var dLat = (double)(lat2 - lat1) * Math.PI / 180.0;
        var dLon = (double)(lon2 - lon1) * Math.PI / 180.0;
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos((double)lat1 * Math.PI / 180.0) * Math.Cos((double)lat2 * Math.PI / 180.0) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return Math.Round(R * c, 1);
    }
}