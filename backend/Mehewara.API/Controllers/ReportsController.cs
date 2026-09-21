using System.Security.Claims;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Reports;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportsController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpPost]
    [Authorize(Roles = "RESIDENT")]
    [ProducesResponseType(typeof(ReportResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> CreateReport([FromBody] CreateReportRequest request)
    {
        var residentId = GetCurrentUserId();
        var response = await _reportService.CreateReportAsync(residentId, request);
        return StatusCode(StatusCodes.Status201Created, response);
    }

    [HttpGet]
    [Authorize(Roles = "ADMIN")]
    [ProducesResponseType(typeof(PagedResult<ReportSummaryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetReports([FromQuery] ReportFilterRequest filter)
    {
        var response = await _reportService.GetReportsAsync(filter);
        return Ok(response);
    }

    [HttpGet("{id:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(ReportResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetReportById(Guid id)
    {
        var userId = GetCurrentUserId();
        var userRole = GetCurrentUserRole();
        var response = await _reportService.GetReportByIdAsync(id, userId, userRole);
        return Ok(response);
    }

    [HttpPost("photos")]
    [Authorize]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ReportPhotoDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UploadReportPhoto(IFormFile file)
    {
        var response = await _reportService.UploadReportPhotoAsync(file);
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

    private string GetCurrentUserRole()
    {
        return User.FindFirstValue(ClaimTypes.Role) ?? "RESIDENT";
    }
}
