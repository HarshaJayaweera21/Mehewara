using Mehewara.API.Common;
using Mehewara.API.Controllers;
using Mehewara.API.DTOs.Problems;
using Mehewara.API.DTOs.Problems.Consolidation;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Mehewara.Tests.Member2.Unit.Controllers;

public class ProblemsControllerTests
{
    private readonly Mock<IProblemService> _mockService;
    private readonly ProblemsController _controller;

    public ProblemsControllerTests()
    {
        // 1. Create a mock of IProblemService using Moq
        _mockService = new Mock<IProblemService>();

        // 2. Inject the mock into the controller
        _controller = new ProblemsController(_mockService.Object);
    }


    // TEST 1: GET /api/problems -> 200 OK

    [Fact]
    public async Task GetProblems_ReturnsOkWithPagedResult()
    {
        // ARRANGE: Instruct the mock to return a sample PagedResult
        var query = new GetProblemsQuery { Page = 1, PageSize = 10 };
        var pagedResult = new PagedResult<ProblemResponse>
        {
            Items = new List<ProblemResponse>
            {
                new() { Id = Guid.NewGuid(), Title = "Road issue", Category = "ROAD", Status = "IDENTIFIED" }
            },
            TotalItems = 1,
            Page = 1,
            PageSize = 10
        };

        _mockService.Setup(s => s.GetProblemsAsync(query))
            .ReturnsAsync(pagedResult);

        // ACT
        var actionResult = await _controller.GetProblems(query);

        // ASSERT: Must be 200 OK with the exact data
        var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
        Assert.Equal(200, okResult.StatusCode);

        var returnedData = Assert.IsType<PagedResult<ProblemResponse>>(okResult.Value);
        Assert.Single(returnedData.Items);
    }


    // TEST 2: GET /api/problems/{id} -> 200 OK

    [Fact]
    public async Task GetProblemById_ReturnsOkWithProblemDetails()
    {
        // ARRANGE
        var problemId = Guid.NewGuid();
        var problemDetail = new ProblemDetailResponse
        {
            Id = problemId,
            Title = "Drainage blockage",
            Category = "DRAINAGE",
            Status = "IDENTIFIED"
        };

        _mockService.Setup(s => s.GetProblemByIdAsync(problemId))
            .ReturnsAsync(problemDetail);

        // ACT
        var actionResult = await _controller.GetProblemById(problemId);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
        Assert.Equal(200, okResult.StatusCode);

        var returnedData = Assert.IsType<ProblemDetailResponse>(okResult.Value);
        Assert.Equal(problemId, returnedData.Id);
    }


    // TEST 3: POST /api/problems -> 201 CreatedAtAction

    [Fact]
    public async Task CreateProblem_ReturnsCreatedAtActionWithNewId()
    {
        // ARRANGE
        var request = new CreateProblemRequest
        {
            Title = "New road crack",
            Category = "ROAD",
            Latitude = 6.9m,
            Longitude = 79.8m
        };

        var createdResponse = new ProblemResponse
        {
            Id = Guid.NewGuid(),
            Title = request.Title,
            Category = request.Category,
            Status = "IDENTIFIED"
        };

        _mockService.Setup(s => s.CreateProblemAsync(request))
            .ReturnsAsync(createdResponse);

        // ACT
        var actionResult = await _controller.CreateProblem(request);

        // ASSERT: Must return HTTP 201 Created with route to GetProblemById
        var createdResult = Assert.IsType<CreatedAtActionResult>(actionResult.Result);
        Assert.Equal(201, createdResult.StatusCode);
        Assert.Equal(nameof(ProblemsController.GetProblemById), createdResult.ActionName);
        Assert.Equal(createdResponse.Id, createdResult.RouteValues?["id"]);
    }


    // TEST 4: GET /api/problems/uncertain-reports -> 200 OK

    [Fact]
    public async Task GetUncertainReports_ReturnsOkWithTriageList()
    {
        // ARRANGE
        var triageReports = new List<UncertainReportResponse>
        {
            new() { ReportId = Guid.NewGuid(), Description = "Needs check", Category = "DRAINAGE" }
        };

        _mockService.Setup(s => s.GetUncertainReportsAsync())
            .ReturnsAsync(triageReports);

        // ACT
        var actionResult = await _controller.GetUncertainReports();

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
        Assert.Equal(200, okResult.StatusCode);

        var returnedData = Assert.IsType<List<UncertainReportResponse>>(okResult.Value);
        Assert.Single(returnedData);
    }

    
    // TEST 5: POST /api/problems/uncertain-reports/link -> 200 OK

    [Fact]
    public async Task LinkUncertainReport_ReturnsOkWithUpdatedProblem()
    {
        // ARRANGE
        var request = new LinkUncertainReportRequest
        {
            ReportId = Guid.NewGuid(),
            ProblemId = Guid.NewGuid(),
            CoordinatorNotes = "Linked after verification"
        };

        var updatedProblem = new ProblemResponse
        {
            Id = request.ProblemId,
            Title = "Existing problem",
            RelatedReportCount = 2
        };

        _mockService.Setup(s => s.LinkUncertainReportAsync(request))
            .ReturnsAsync(updatedProblem);

        // ACT
        var actionResult = await _controller.LinkUncertainReport(request);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(actionResult.Result);
        Assert.Equal(200, okResult.StatusCode);

        var returnedData = Assert.IsType<ProblemResponse>(okResult.Value);
        Assert.Equal(2, returnedData.RelatedReportCount);
    }

    
    // TEST 6: POST /api/problems/uncertain-reports/{id}/cancel -> 200 OK

    [Fact]
    public async Task CancelUncertainReport_ReturnsOk()
    {
        // ARRANGE
        var reportId = Guid.NewGuid();
        var request = new CancelUncertainReportRequest
        {
            ReportId = reportId,
            Reason = "Spam report"
        };

        _mockService.Setup(s => s.CancelUncertainReportAsync(reportId, request.Reason))
            .Returns(Task.CompletedTask);

        // ACT
        var actionResult = await _controller.CancelUncertainReport(reportId, request);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(actionResult);
        Assert.Equal(200, okResult.StatusCode);

        // Verify service was called once
        _mockService.Verify(s => s.CancelUncertainReportAsync(reportId, request.Reason), Times.Once);
    }
}
