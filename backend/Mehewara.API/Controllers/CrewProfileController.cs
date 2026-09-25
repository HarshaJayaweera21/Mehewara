using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/crew")]
[Authorize(Roles = "ADMIN,CREW_LEADER_DRAINAGE,CREW_LEADER_ROAD,CREW_LEADER_WASTE,CREW_LEADER_ELECTRICAL,CREW_LEADER_ENVIRONMENT")]
public class CrewProfileController : ControllerBase
{
    private readonly ICrewService _crewService;
    private readonly ILogger<CrewProfileController> _logger;

    public CrewProfileController(ICrewService crewService, ILogger<CrewProfileController> logger)
    {
        _crewService = crewService;
        _logger = logger;
    }

    private Guid GetCurrentUserId()
    {
        var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier) 
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue("sub");

        if (string.IsNullOrWhiteSpace(claimValue) || !Guid.TryParse(claimValue, out var userId))
        {
            throw new UnauthorizedException("Unable to determine user identity from authorization token.", "INVALID_TOKEN_CLAIMS");
        }
        return userId;
    }

    [HttpGet("profile")]
    [ProducesResponseType(typeof(CrewDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetMyCrewProfile()
    {
        var userId = GetCurrentUserId();
        var crew = await _crewService.GetCrewByLeaderUserIdAsync(userId);

        if (crew == null)
        {
            // If admin is testing or checking, fallback to first crew or return 404
            if (User.IsInRole("ADMIN"))
            {
                var allCrews = await _crewService.GetCrewsAsync(new CrewQueryParams { Page = 1, PageSize = 1 });
                if (allCrews.Items.Count > 0)
                {
                    crew = await _crewService.GetCrewByIdAsync(allCrews.Items[0].Id);
                }
            }

            if (crew == null)
            {
                throw new NotFoundException("No municipal crew record is associated with the authenticated crew leader account.", "CREW_PROFILE_NOT_FOUND");
            }
        }

        return Ok(crew);
    }

    [HttpPatch("status")]
    [ProducesResponseType(typeof(CrewDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UpdateMyCrewStatus([FromBody] UpdateCrewStatusRequestDto request)
    {
        var userId = GetCurrentUserId();
        var crew = await _crewService.GetCrewByLeaderUserIdAsync(userId);

        if (crew == null && User.IsInRole("ADMIN"))
        {
            var allCrews = await _crewService.GetCrewsAsync(new CrewQueryParams { Page = 1, PageSize = 1 });
            if (allCrews.Items.Count > 0)
            {
                crew = await _crewService.GetCrewByIdAsync(allCrews.Items[0].Id);
            }
        }

        if (crew == null)
        {
            throw new NotFoundException("No municipal crew is assigned to this user.", "CREW_NOT_FOUND");
        }

        var updated = await _crewService.UpdateCrewStatusAsync(crew.Id, request.Status);
        return Ok(updated);
    }

    [HttpGet("work-orders")]
    [ProducesResponseType(typeof(List<CrewWorkOrderItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetMyCrewWorkOrders()
    {
        var userId = GetCurrentUserId();
        var crew = await _crewService.GetCrewByLeaderUserIdAsync(userId);

        if (crew == null && User.IsInRole("ADMIN"))
        {
            var allCrews = await _crewService.GetCrewsAsync(new CrewQueryParams { Page = 1, PageSize = 1 });
            if (allCrews.Items.Count > 0)
            {
                crew = await _crewService.GetCrewByIdAsync(allCrews.Items[0].Id);
            }
        }

        if (crew == null)
        {
            throw new NotFoundException("No municipal crew is assigned to this user.", "CREW_NOT_FOUND");
        }

        var workOrders = await _crewService.GetCrewWorkOrdersAsync(crew.Id);
        return Ok(workOrders);
    }
}
