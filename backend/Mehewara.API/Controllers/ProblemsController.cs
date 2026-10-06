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
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult<IEnumerable<ProblemReportResponse>>> GetReportsByProblemId(Guid id)
    {
        var result = await _problemService.GetReportsByProblemIdAsync(id);
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "ADMIN")]
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
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult<IEnumerable<Mehewara.API.DTOs.Problems.Consolidation.UncertainReportResponse>>> GetUncertainReports()
    {
        var result = await _problemService.GetUncertainReportsAsync();
        return Ok(result);
    }

    [HttpPost("uncertain-reports/link")]
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult<ProblemResponse>> LinkUncertainReport(
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.LinkUncertainReportRequest request)
    {
        var result = await _problemService.LinkUncertainReportAsync(request);
        return Ok(result);
    }

    [HttpPost("uncertain-reports/create")]
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult<ProblemResponse>> CreateProblemFromUncertainReport(
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.CreateProblemFromUncertainReportRequest request)
    {
        var result = await _problemService.CreateProblemFromUncertainReportAsync(request);
        return CreatedAtAction(
            nameof(GetProblemById),
            new { id = result.Id },
            result);
    }

    [HttpPost("uncertain-reports/{id:guid}/cancel")]
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult> CancelUncertainReport(
        Guid id,
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.CancelUncertainReportRequest? request = null)
    {
        var reportId = id != Guid.Empty ? id : (request?.ReportId ?? Guid.Empty);
        await _problemService.CancelUncertainReportAsync(reportId, request?.Reason);
        return Ok(new { message = "Report cancelled successfully.", reportId, status = "CANCELLED" });
    }

    [HttpPost("uncertain-reports/cancel")]
    [Authorize(Roles = "ADMIN")]
    public async Task<ActionResult> CancelUncertainReportByBody(
        [FromBody] Mehewara.API.DTOs.Problems.Consolidation.CancelUncertainReportRequest request)
    {
        await _problemService.CancelUncertainReportAsync(request.ReportId, request.Reason);
        return Ok(new { message = "Report cancelled successfully.", reportId = request.ReportId, status = "CANCELLED" });
    }
}