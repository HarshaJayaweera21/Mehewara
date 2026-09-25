using Mehewara.API.Common;
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

    [HttpGet]
    public async Task<ActionResult<PagedResult<ProblemResponse>>> GetProblems(
        [FromQuery] GetProblemsQuery query)
    {
        var result = await _problemService.GetProblemsAsync(query);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ProblemDetailResponse>> GetProblemById(Guid id)
    {
        var result = await _problemService.GetProblemByIdAsync(id);
        return Ok(result);
    }

    [HttpGet("{id:guid}/reports")]
    public async Task<ActionResult<IEnumerable<ProblemReportResponse>>> GetReportsByProblemId(Guid id)
    {
        var result = await _problemService.GetReportsByProblemIdAsync(id);
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<ProblemResponse>> CreateProblem(
        CreateProblemRequest request)
    {
        var result = await _problemService.CreateProblemAsync(request);

        return CreatedAtAction(
            nameof(GetProblemById),
            new { id = result.Id },
            result);
    }

    [HttpGet("uncertain-reports")]
    public async Task<ActionResult<IEnumerable<Mehewara.API.DTOs.Problems.Consolidation.UncertainReportResponse>>> GetUncertainReports()
    {
        var result = await _problemService.GetUncertainReportsAsync();
        return Ok(result);
    }

    [HttpPost("uncertain-reports/link")]
    public async Task<ActionResult<ProblemResponse>> LinkUncertainReport(
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.LinkUncertainReportRequest request)
    {
        var result = await _problemService.LinkUncertainReportAsync(request);
        return Ok(result);
    }

    [HttpPost("uncertain-reports/create")]
    public async Task<ActionResult<ProblemResponse>> CreateProblemFromUncertainReport(
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.CreateProblemFromUncertainReportRequest request)
    {
        var result = await _problemService.CreateProblemFromUncertainReportAsync(request);
        return CreatedAtAction(
            nameof(GetProblemById),
            new { id = result.Id },
            result);
    }
}