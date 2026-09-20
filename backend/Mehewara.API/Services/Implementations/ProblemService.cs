using Mehewara.API.Common;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems;
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
}