using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.Crew;

public class UpdateCrewStatusRequestDto
{
    [Required]
    public string Status { get; set; } = string.Empty;
}
