using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public class CrewService : ICrewService
{
    private readonly AppDbContext _context;
    private readonly ILogger<CrewService> _logger;

    public CrewService(AppDbContext context, ILogger<CrewService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<PagedResult<CrewListItemDto>> GetCrewsAsync(CrewQueryParams query)
    {
        var queryable = _context.Crews
            .Include(c => c.CrewLeaderUser)
            .AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.CrewType))
        {
            var typeUpper = query.CrewType.Trim().ToUpperInvariant();
            queryable = queryable.Where(c => c.CrewType.ToUpper() == typeUpper);
        }

        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            var statusUpper = query.Status.Trim().ToUpperInvariant();
            queryable = queryable.Where(c => c.Status.ToUpper() == statusUpper);
        }

        var isAscending = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase);
        queryable = (query.SortBy?.ToLowerInvariant()) switch
        {
            "name" => isAscending ? queryable.OrderBy(c => c.CrewName) : queryable.OrderByDescending(c => c.CrewName),
            "crewtype" => isAscending ? queryable.OrderBy(c => c.CrewType) : queryable.OrderByDescending(c => c.CrewType),
            "status" => isAscending ? queryable.OrderBy(c => c.Status) : queryable.OrderByDescending(c => c.Status),
            _ => isAscending ? queryable.OrderBy(c => c.CreatedAt) : queryable.OrderByDescending(c => c.CreatedAt)
        };

        var totalItems = await queryable.CountAsync();
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = query.PageSize < 1 ? 20 : query.PageSize;

        var crews = await queryable
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var crewIds = crews.Select(c => c.CrewId).ToList();

        var activeWorkOrders = await _context.WorkOrders
            .AsNoTracking()
            .Where(w => crewIds.Contains(w.CrewId) && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .GroupBy(w => w.CrewId)
            .Select(g => new
            {
                CrewId = g.Key,
                WorkOrderId = g.OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
                               .Select(w => w.WorkOrderId)
                               .FirstOrDefault()
            })
            .ToDictionaryAsync(x => x.CrewId, x => x.WorkOrderId);

        var items = crews.Select(c => new CrewListItemDto
        {
            Id = c.CrewId,
            Name = c.CrewName,
            CrewType = c.CrewType,
            Status = c.Status,
            CrewLeaderUserId = c.CrewLeaderUserId,
            ActiveWorkOrderId = activeWorkOrders.TryGetValue(c.CrewId, out var woId) ? woId : null
        }).ToList();

        return new PagedResult<CrewListItemDto>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            SortBy = query.SortBy ?? "createdAt",
            SortDirection = query.SortDirection ?? "desc"
        };
    }

    public async Task<CrewDetailDto?> GetCrewByIdAsync(Guid crewId)
    {
        var crew = await _context.Crews
            .Include(c => c.CrewLeaderUser)
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.CrewId == crewId);

        if (crew == null)
        {
            return null;
        }

        var activeWorkOrderId = await _context.WorkOrders
            .AsNoTracking()
            .Where(w => w.CrewId == crewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
            .Select(w => (Guid?)w.WorkOrderId)
            .FirstOrDefaultAsync();

        return new CrewDetailDto
        {
            Id = crew.CrewId,
            Name = crew.CrewName,
            CrewType = crew.CrewType,
            Status = crew.Status,
            CrewLeaderUserId = crew.CrewLeaderUserId,
            CrewLeaderName = crew.CrewLeaderUser != null
                ? $"{crew.CrewLeaderUser.FirstName} {crew.CrewLeaderUser.LastName}".Trim()
                : null,
            Description = crew.Description,
            ContactNumber = crew.ContactNumber,
            ActiveWorkOrderId = activeWorkOrderId
        };
    }

    public async Task<List<CrewAvailabilityDto>> GetAvailableCrewsAsync(string? crewType, string? status)
    {
        var queryable = _context.Crews.AsNoTracking();

        var targetStatus = string.IsNullOrWhiteSpace(status) ? "AVAILABLE" : status.Trim().ToUpperInvariant();
        queryable = queryable.Where(c => c.Status.ToUpper() == targetStatus);

        if (!string.IsNullOrWhiteSpace(crewType))
        {
            var typeUpper = crewType.Trim().ToUpperInvariant();
            queryable = queryable.Where(c => c.CrewType.ToUpper() == typeUpper);
        }

        var crews = await queryable.OrderBy(c => c.CrewName).ToListAsync();
        var crewIds = crews.Select(c => c.CrewId).ToList();

        var activeWorkOrders = await _context.WorkOrders
            .AsNoTracking()
            .Where(w => crewIds.Contains(w.CrewId) && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .GroupBy(w => w.CrewId)
            .Select(g => new
            {
                CrewId = g.Key,
                WorkOrderId = g.OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
                               .Select(w => w.WorkOrderId)
                               .FirstOrDefault()
            })
            .ToDictionaryAsync(x => x.CrewId, x => x.WorkOrderId);

        return crews.Select(c => new CrewAvailabilityDto
        {
            CrewId = c.CrewId,
            Name = c.CrewName,
            CrewType = c.CrewType,
            Status = c.Status,
            ActiveWorkOrderId = activeWorkOrders.TryGetValue(c.CrewId, out var woId) ? woId : null
        }).ToList();
    }

    public async Task<CrewDetailDto?> GetCrewByLeaderUserIdAsync(Guid userId)
    {
        var crew = await _context.Crews
            .Include(c => c.CrewLeaderUser)
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.CrewLeaderUserId == userId);

        if (crew == null)
        {
            return null;
        }

        var activeWorkOrderId = await _context.WorkOrders
            .AsNoTracking()
            .Where(w => w.CrewId == crew.CrewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
            .Select(w => (Guid?)w.WorkOrderId)
            .FirstOrDefaultAsync();

        return new CrewDetailDto
        {
            Id = crew.CrewId,
            Name = crew.CrewName,
            CrewType = crew.CrewType,
            Status = crew.Status,
            CrewLeaderUserId = crew.CrewLeaderUserId,
            CrewLeaderName = crew.CrewLeaderUser != null
                ? $"{crew.CrewLeaderUser.FirstName} {crew.CrewLeaderUser.LastName}".Trim()
                : null,
            Description = crew.Description,
            ContactNumber = crew.ContactNumber,
            ActiveWorkOrderId = activeWorkOrderId
        };
    }

    public async Task<CrewDetailDto> UpdateCrewStatusAsync(Guid crewId, string newStatus)
    {
        var normalized = newStatus?.Trim().ToUpperInvariant();
        if (normalized != "AVAILABLE" && normalized != "UNAVAILABLE" && normalized != "BUSY")
        {
            throw new Mehewara.API.Exceptions.ValidationException("Invalid crew status. Allowed values are AVAILABLE, BUSY, UNAVAILABLE.", "INVALID_CREW_STATUS");
        }

        var crew = await _context.Crews
            .Include(c => c.CrewLeaderUser)
            .FirstOrDefaultAsync(c => c.CrewId == crewId);

        if (crew == null)
        {
            throw new Mehewara.API.Exceptions.NotFoundException($"Crew with ID '{crewId}' was not found.", "CREW_NOT_FOUND");
        }

        var hasActiveJob = await _context.WorkOrders
            .AnyAsync(w => w.CrewId == crewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"));

        if (hasActiveJob && normalized == "UNAVAILABLE")
        {
            throw new Mehewara.API.Exceptions.ConflictException("Cannot set crew status to UNAVAILABLE while an active work order is currently assigned or in progress.", "ACTIVE_WORK_ORDER_EXISTS");
        }

        if (hasActiveJob && normalized == "AVAILABLE")
        {
            throw new Mehewara.API.Exceptions.ConflictException("Cannot set crew status to AVAILABLE while an active work order is currently underway.", "ACTIVE_WORK_ORDER_EXISTS");
        }

        crew.Status = normalized;
        crew.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var activeWorkOrderId = await _context.WorkOrders
            .AsNoTracking()
            .Where(w => w.CrewId == crew.CrewId && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
            .Select(w => (Guid?)w.WorkOrderId)
            .FirstOrDefaultAsync();

        return new CrewDetailDto
        {
            Id = crew.CrewId,
            Name = crew.CrewName,
            CrewType = crew.CrewType,
            Status = crew.Status,
            CrewLeaderUserId = crew.CrewLeaderUserId,
            CrewLeaderName = crew.CrewLeaderUser != null
                ? $"{crew.CrewLeaderUser.FirstName} {crew.CrewLeaderUser.LastName}".Trim()
                : null,
            Description = crew.Description,
            ContactNumber = crew.ContactNumber,
            ActiveWorkOrderId = activeWorkOrderId
        };
    }

    public async Task<List<CrewWorkOrderItemDto>> GetCrewWorkOrdersAsync(Guid crewId)
    {
        var workOrders = await _context.WorkOrders
            .Include(w => w.Problem)
            .AsNoTracking()
            .Where(w => w.CrewId == crewId)
            .OrderByDescending(w => w.AssignedAt ?? w.CreatedAt)
            .ToListAsync();

        return workOrders.Select(w => new CrewWorkOrderItemDto
        {
            Id = w.WorkOrderId,
            ProblemId = w.ProblemId,
            Title = w.Title,
            ProblemTitle = w.Problem?.Title ?? w.Title,
            ProblemCategory = w.Problem?.Category,
            ProblemAddress = w.Problem?.Address,
            Priority = w.Priority,
            Status = w.Status,
            Instructions = w.Instructions,
            AssignedAt = w.AssignedAt,
            StartedAt = w.StartedAt,
            CompletedAt = w.CompletedAt,
            CompletionNotes = w.CompletionNotes,
            CreatedAt = w.CreatedAt
        }).ToList();
    }
}

