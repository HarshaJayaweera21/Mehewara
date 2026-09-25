using System.Security.Claims;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Reports;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/resident/reports")]
public class ResidentReportsController : ControllerBase
{
    private readonly IReportService _reportService;

    public ResidentReportsController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpGet]
    [Authorize(Roles = "RESIDENT")]
    [ProducesResponseType(typeof(PagedResult<ReportSummaryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetMyReports(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? status = null,
        [FromQuery] string? sortBy = "createdAt",
        [FromQuery] string? sortDirection = "desc")
    {
        var residentId = GetCurrentUserId();
        var response = await _reportService.GetResidentReportsAsync(residentId, page, pageSize, status, sortBy, sortDirection);
        return Ok(response);
    }

    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");

        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            throw new UnauthorizedException("User identifier claim is missing or invalid.");
        }

        return userId;
    }
}
