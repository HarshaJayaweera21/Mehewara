using System.Security.Claims;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Services.Implementations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController, Authorize(Roles = "ADMIN"), Route("api/dispatch")]
public class DispatchReviewController(AiReviewService review) : ControllerBase
{
    [HttpPost("recommendations/{id:guid}/validate")]
    public async Task<IActionResult> Validate(Guid id, [FromBody] ReviewRequest request)
    {
        var actor = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub")!);
        var job = await review.EnqueueAsync(id, request, actor, "VALIDATE");
        return Accepted($"/api/dispatch/review-jobs/{job.Id}", new { jobId = job.Id, job.Status, statusUrl = $"/api/dispatch/review-jobs/{job.Id}" });
    }

    [HttpGet("review-jobs/{id:guid}")]
    public async Task<IActionResult> Job(Guid id)
    {
        var job = await review.GetJobAsync(id);
        return job == null ? NotFound() : Ok(job);
    }
}
