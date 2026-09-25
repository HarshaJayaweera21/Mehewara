namespace Mehewara.API.DTOs.Crew;

public class CrewAvailabilityDto
{
    public Guid CrewId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string CrewType { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public Guid? ActiveWorkOrderId { get; set; }
}
