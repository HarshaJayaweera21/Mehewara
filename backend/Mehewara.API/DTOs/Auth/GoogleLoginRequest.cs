using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Auth;

public class GoogleLoginRequest
{
    [Required]
    public string IdToken { get; set; } = string.Empty;
}
