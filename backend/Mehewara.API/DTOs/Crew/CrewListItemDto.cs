namespace Mehewara.API.DTOs.Crew;

public class CrewListItemDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string CrewType { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public Guid? CrewLeaderUserId { get; set; }
    public Guid? ActiveWorkOrderId { get; set; }
}
