namespace Mehewara.API.Models;

public class Crew
{
    public Guid CrewId { get; set; }
    public string CrewName { get; set; } = string.Empty;
    public string CrewType { get; set; } = string.Empty;
    public Guid? CrewLeaderUserId { get; set; }
    public string? Description { get; set; }
    public string? ContactNumber { get; set; }
    public string Status { get; set; } = "AVAILABLE";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public User? CrewLeaderUser { get; set; }
    public ICollection<WorkOrder> WorkOrders { get; set; }
        = new List<WorkOrder>();
}