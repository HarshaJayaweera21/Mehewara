using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Crew;

namespace Mehewara.API.Services.Interfaces;

public interface ICrewService
{
    Task<PagedResult<CrewListItemDto>> GetCrewsAsync(CrewQueryParams query);
    Task<CrewDetailDto?> GetCrewByIdAsync(Guid crewId);
    Task<CrewDetailDto?> GetCrewByLeaderUserIdAsync(Guid userId);
    Task<List<CrewAvailabilityDto>> GetAvailableCrewsAsync(string? crewType, string? status);
    Task<CrewDetailDto> UpdateCrewStatusAsync(Guid crewId, string newStatus);
    Task<List<CrewWorkOrderItemDto>> GetCrewWorkOrdersAsync(Guid crewId);
}
