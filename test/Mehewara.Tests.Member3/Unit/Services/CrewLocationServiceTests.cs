using Mehewara.API.Services.Implementations;
using Microsoft.Extensions.Caching.Memory;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Services;

public class CrewLocationServiceTests
{
    private readonly IMemoryCache _memoryCache;
    private readonly CrewLocationService _service;

    public CrewLocationServiceTests()
    {
        _memoryCache = new MemoryCache(new MemoryCacheOptions());
        _service = new CrewLocationService(_memoryCache);
    }

    [Fact]
    public void RecordHeartbeat_StoresCoordinatesInCache()
    {
        // ARRANGE
        var crewId = Guid.NewGuid();
        decimal lat = 6.9319m;
        decimal lon = 79.8478m;

        // ACT
        _service.RecordHeartbeat(crewId, lat, lon);

        // ASSERT
        var (cachedLat, cachedLon) = _service.GetCurrentLocation(crewId);
        Assert.Equal(lat, cachedLat);
        Assert.Equal(lon, cachedLon);
    }

    [Fact]
    public void GetCurrentLocation_UncachedCrew_ReturnsDefaultColomboMunicipalDepotCoordinates()
    {
        // ARRANGE
        var unknownCrewId = Guid.NewGuid();

        // ACT
        var (lat, lon) = _service.GetCurrentLocation(unknownCrewId);

        // ASSERT
        // Default Colombo Municipal Depot coordinates: (6.927079, 79.861244)
        Assert.Equal(6.927079m, lat);
        Assert.Equal(79.861244m, lon);
    }

    [Fact]
    public void RecordHeartbeat_MultipleCrews_MaintainsDistinctCoordinates()
    {
        // ARRANGE
        var crew1 = Guid.NewGuid();
        var crew2 = Guid.NewGuid();

        // ACT
        _service.RecordHeartbeat(crew1, 6.9100m, 79.8500m);
        _service.RecordHeartbeat(crew2, 6.9400m, 79.8700m);

        // ASSERT
        var loc1 = _service.GetCurrentLocation(crew1);
        var loc2 = _service.GetCurrentLocation(crew2);

        Assert.Equal(6.9100m, loc1.Latitude);
        Assert.Equal(79.8500m, loc1.Longitude);

        Assert.Equal(6.9400m, loc2.Latitude);
        Assert.Equal(79.8700m, loc2.Longitude);
    }
}
