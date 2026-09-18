using Mehewara.API.DTOs.Problems;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mehewara.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProblemsController : ControllerBase
{
    private readonly IProblemService _problemService;

    public ProblemsController(IProblemService problemService)
    {
        _problemService = problemService;
    }

    [HttpPost]
    public async Task<ActionResult<ProblemResponse>> CreateProblem(
        CreateProblemRequest request)
    {
        var result = await _problemService.CreateProblemAsync(request);

        return StatusCode(StatusCodes.Status201Created, result);
    }
}