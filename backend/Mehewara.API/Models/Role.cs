namespace Mehewara.API.Models;

public class Role
{
    public Guid RoleId { get; set; }

    public string RoleName { get; set; } = string.Empty;

    public string RoleCode { get; set; } = string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; }

    public ICollection<User> Users { get; set; } = new List<User>();
}