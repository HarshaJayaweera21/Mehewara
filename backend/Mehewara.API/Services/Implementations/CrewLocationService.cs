using Microsoft.Extensions.Caching.Memory;
using Mehewara.API.Services.Interfaces;

namespace Mehewara.API.Services.Implementations;

public class CrewLocationService : ICrewLocationService
{
    private readonly IMemoryCache _memoryCache;
    // Default Colombo Municipal Works Depot coordinates (6.9271° N, 79.8612° E)
    private static readonly (decimal Latitude, decimal Longitude) DefaultDepot = (6.927079m, 79.861244m);
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(20);

    public CrewLocationService(IMemoryCache memoryCache)
    {
        _memoryCache = memoryCache;
    }

    public void RecordHeartbeat(Guid crewId, decimal latitude, decimal longitude)
    {
        _memoryCache.Set($"crew_gps_{crewId}", (latitude, longitude), CacheDuration);
    }

    public (decimal Latitude, decimal Longitude) GetCurrentLocation(Guid crewId)
    {
        if (_memoryCache.TryGetValue($"crew_gps_{crewId}", out (decimal Latitude, decimal Longitude) coords))
        {
            return coords;
        }
        return DefaultDepot;
    }
}
