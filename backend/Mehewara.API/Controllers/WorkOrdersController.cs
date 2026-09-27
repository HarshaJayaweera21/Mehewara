using System.Security.Claims;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/work-orders")]
[Authorize]
public class WorkOrdersController : ControllerBase
{
    private readonly IWorkOrderService _orders;
    public WorkOrdersController(IWorkOrderService orders) => _orders = orders;

    [HttpGet]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> List([FromQuery] WorkOrderQuery query) => Ok(await _orders.GetAdminOrdersAsync(query));

    [HttpGet("{id:guid}")]
    [Authorize(Roles = CrewRoles.AllWithAdmin)]
    public async Task<IActionResult> Detail(Guid id) =>
        Ok(await _orders.GetOrderAsync(id, UserId(), User.IsInRole("ADMIN")));

    [HttpPost("{id:guid}/start")]
    [Authorize(Roles = CrewRoles.All)]
    public async Task<IActionResult> Start(Guid id) => Ok(await _orders.StartAsync(id, UserId()));

    [HttpPost("{id:guid}/complete")]
    [Authorize(Roles = CrewRoles.All)]
    public async Task<IActionResult> Complete(Guid id, [FromBody] CompleteWorkOrderRequest request) =>
        Ok(await _orders.CompleteAsync(id, UserId(), request));

    private Guid UserId() => Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
        ? id : throw new UnauthorizedException("User identifier claim is missing or invalid.");
}

[ApiController]
[Route("api/crew/work-orders")]
[Authorize(Roles = CrewRoles.All)]
public class CrewWorkOrdersController : ControllerBase
{
    private readonly IWorkOrderService _orders;
    public CrewWorkOrdersController(IWorkOrderService orders) => _orders = orders;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] WorkOrderQuery query)
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(claim, out var userId))
            throw new UnauthorizedException("User identifier claim is missing or invalid.");
        return Ok(await _orders.GetCrewOrdersAsync(query, userId));
    }
}

internal static class CrewRoles
{
    public const string All = "CREW_LEADER_DRAINAGE,CREW_LEADER_ROAD,CREW_LEADER_WASTE,CREW_LEADER_ELECTRICAL,CREW_LEADER_ENVIRONMENT";
    public const string AllWithAdmin = "ADMIN," + All;
}
