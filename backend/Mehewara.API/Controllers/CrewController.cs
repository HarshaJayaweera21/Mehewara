using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/crews")]
[Authorize(Roles = "ADMIN")]
public class CrewController : ControllerBase
{
    private readonly ICrewService _crewService;

    public CrewController(ICrewService crewService)
    {
        _crewService = crewService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<CrewListItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetCrews([FromQuery] CrewQueryParams query)
    {
        var result = await _crewService.GetCrewsAsync(query);
        return Ok(result);
    }

    [HttpGet("availability")]
    [ProducesResponseType(typeof(CrewAvailabilityResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetAvailability([FromQuery] string? crewType, [FromQuery] string? status)
    {
        var items = await _crewService.GetAvailableCrewsAsync(crewType, status);
        return Ok(new CrewAvailabilityResponseDto { Items = items });
    }

    [HttpGet("{crewId:guid}")]
    [ProducesResponseType(typeof(CrewDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetCrewById([FromRoute] Guid crewId)
    {
        var crew = await _crewService.GetCrewByIdAsync(crewId);
        if (crew == null)
        {
            throw new NotFoundException($"Crew with ID '{crewId}' was not found.", "CREW_NOT_FOUND");
        }
        return Ok(crew);
    }
}
