using System.Security.Claims;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/dispatch")]
[Authorize(Roles = "ADMIN")]
public class DispatchController : ControllerBase
{
    private readonly IDispatchService _dispatchService;

    public DispatchController(IDispatchService dispatchService)
    {
        _dispatchService = dispatchService;
    }

    [HttpGet("recommendations")]
    [ProducesResponseType(typeof(PagedResult<RecommendationListItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetRecommendations([FromQuery] RecommendationQueryParams query)
    {
        var result = await _dispatchService.GetRecommendationsAsync(query);
        return Ok(result);
    }

    [HttpGet("recommendations/{recommendationId:guid}")]
    [ProducesResponseType(typeof(RecommendationDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRecommendationById([FromRoute] Guid recommendationId)
    {
        var result = await _dispatchService.GetRecommendationByIdAsync(recommendationId);
        if (result == null)
        {
            throw new NotFoundException("The requested recommendation was not found.", "RECOMMENDATION_NOT_FOUND");
        }
        return Ok(result);
    }

    [HttpPatch("recommendations/{recommendationId:guid}")]
    [ProducesResponseType(typeof(RecommendationDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> EditRecommendation([FromRoute] Guid recommendationId, [FromBody] EditRecommendationRequest request)
    {
        var adminUserId = GetCurrentUserId();
        var result = await _dispatchService.EditRecommendationAsync(recommendationId, request, adminUserId);
        return Ok(result);
    }

    [HttpPost("recommendations/{recommendationId:guid}/approve")]
    [ProducesResponseType(typeof(ApproveRecommendationResponseDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<IActionResult> ApproveRecommendation([FromRoute] Guid recommendationId, [FromBody] ApproveRecommendationRequest request)
    {
        var adminUserId = GetCurrentUserId();
        var result = await _dispatchService.ApproveRecommendationAsync(recommendationId, request, adminUserId);
        return StatusCode(StatusCodes.Status201Created, result);
    }

    [HttpPost("recommendations/{recommendationId:guid}/reject")]
    [ProducesResponseType(typeof(RejectRecommendationResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RejectRecommendation([FromRoute] Guid recommendationId, [FromBody] RejectRecommendationRequest request)
    {
        var adminUserId = GetCurrentUserId();
        var result = await _dispatchService.RejectRecommendationAsync(recommendationId, request, adminUserId);
        return Ok(result);
    }

    [HttpPost("recommendations/{recommendationId:guid}/regenerate")]
    [ProducesResponseType(typeof(RegenerateRecommendationResponseDto), StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RegenerateRecommendation([FromRoute] Guid recommendationId, [FromBody] RegenerateRecommendationRequest request)
    {
        var adminUserId = GetCurrentUserId();
        var result = await _dispatchService.RegenerateRecommendationAsync(recommendationId, request, adminUserId);
        return Accepted(result);
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
