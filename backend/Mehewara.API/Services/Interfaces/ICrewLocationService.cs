namespace Mehewara.API.Services.Interfaces;

public interface ICrewLocationService
{
    void RecordHeartbeat(Guid crewId, decimal latitude, decimal longitude);
    (decimal Latitude, decimal Longitude) GetCurrentLocation(Guid crewId);
}
