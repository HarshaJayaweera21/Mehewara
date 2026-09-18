using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Auth;

public class UpdateProfileRequest
{
    [MaxLength(100)]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    public string? LastName { get; set; }

    [Phone]
    [MaxLength(20)]
    public string? PhoneNumber { get; set; }

    [Url]
    [MaxLength(500)]
    public string? ProfileImageUrl { get; set; }
}
