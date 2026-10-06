using System.Security.Claims;
using Mehewara.API.Controllers;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Controllers;

public class DispatchControllerTests
{
    private readonly Mock<IDispatchService> _mockDispatchService;
    private readonly DispatchController _controller;
    private readonly Guid _adminUserId = Guid.NewGuid();

    public DispatchControllerTests()
    {
        _mockDispatchService = new Mock<IDispatchService>();
        _controller = new DispatchController(_mockDispatchService.Object);

        SetAdminContext(_adminUserId);
    }

    private void SetAdminContext(Guid userId)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, "ADMIN")
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = principal }
        };
    }

    [Fact]
    public async Task GetRecommendations_ReturnsOkWithPagedResult()
    {
        // ARRANGE
        var query = new RecommendationQueryParams { Page = 1, PageSize = 10 };
        var paged = new PagedResult<RecommendationListItemDto>
        {
            Items = new List<RecommendationListItemDto>
            {
                new()
                {
                    RecommendationId = Guid.NewGuid(),
                    ProblemId = Guid.NewGuid(),
                    ProblemTitle = "Flooded junction",
                    Priority = "HIGH",
                    PriorityScore = 78,
                    RequiredCrewType = "DRAINAGE",
                    CanApprove = true
                }
            },
            TotalItems = 1,
            Page = 1,
            PageSize = 10
        };

        _mockDispatchService.Setup(s => s.GetRecommendationsAsync(query))
            .ReturnsAsync(paged);

        // ACT
        var result = await _controller.GetRecommendations(query);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<PagedResult<RecommendationListItemDto>>(okResult.Value);
        Assert.Single(data.Items);
        Assert.Equal("HIGH", data.Items[0].Priority);
    }

    [Fact]
    public async Task GetRecommendationById_Existing_ReturnsOkWithDetail()
    {
        // ARRANGE
        var recId = Guid.NewGuid();
        var detail = new RecommendationDetailDto
        {
            RecommendationId = recId,
            ProblemId = Guid.NewGuid(),
            ProblemTitle = "Severe road cave-in",
            Priority = "CRITICAL",
            PriorityScore = 92,
            RequiredCrewType = "ROAD",
            RecommendedCrewName = "Road Maintenance Crew Bravo"
        };

        _mockDispatchService.Setup(s => s.GetRecommendationByIdAsync(recId))
            .ReturnsAsync(detail);

        // ACT
        var result = await _controller.GetRecommendationById(recId);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<RecommendationDetailDto>(okResult.Value);
        Assert.Equal(recId, data.RecommendationId);
        Assert.Equal("CRITICAL", data.Priority);
    }

    [Fact]
    public async Task GetRecommendationById_NonExistent_ThrowsNotFoundException()
    {
        // ARRANGE
        var missingId = Guid.NewGuid();
        _mockDispatchService.Setup(s => s.GetRecommendationByIdAsync(missingId))
            .ReturnsAsync((RecommendationDetailDto?)null);

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<NotFoundException>(() => _controller.GetRecommendationById(missingId));
        Assert.Equal("RECOMMENDATION_NOT_FOUND", ex.ErrorCode);
    }

    [Fact]
    public async Task EditRecommendation_ValidRequest_CallsServiceWithAdminIdAndReturnsDetail()
    {
        // ARRANGE
        var recId = Guid.NewGuid();
        var request = new EditRecommendationRequest
        {
            Priority = "HIGH",
            PriorityScore = 75,
            EditReason = "Reassessed based on updated resident reports",
            ExpectedRevision = 1
        };
        var updatedDetail = new RecommendationDetailDto
        {
            RecommendationId = recId,
            Priority = "HIGH",
            PriorityScore = 75,
            Origin = "HumanOverride"
        };

        _mockDispatchService.Setup(s => s.EditRecommendationAsync(recId, request, _adminUserId))
            .ReturnsAsync(updatedDetail);

        // ACT
        var result = await _controller.EditRecommendation(recId, request);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<RecommendationDetailDto>(okResult.Value);
        Assert.Equal("HumanOverride", data.Origin);
    }

    [Fact]
    public async Task ApproveRecommendation_ValidApproval_Returns201CreatedWithWorkOrder()
    {
        // ARRANGE
        var recId = Guid.NewGuid();
        var request = new ApproveRecommendationRequest
        {
            Reason = "Approved after field coordinator verification",
            ExpectedRevision = 1,
            Instructions = "Clear debris immediately"
        };
        var approveResponse = new ApproveRecommendationResponseDto
        {
            RecommendationId = recId,
            Decision = "APPROVED",
            DecidedBy = _adminUserId,
            DecidedAt = DateTime.UtcNow,
            WorkOrder = new WorkOrderSummaryDto
            {
                Id = Guid.NewGuid(),
                ProblemId = Guid.NewGuid(),
                CrewId = Guid.NewGuid(),
                Status = "ASSIGNED"
            }
        };

        _mockDispatchService.Setup(s => s.ApproveRecommendationAsync(recId, request, _adminUserId))
            .ReturnsAsync(approveResponse);

        // ACT
        var result = await _controller.ApproveRecommendation(recId, request);

        // ASSERT
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(201, statusResult.StatusCode);

        var data = Assert.IsType<ApproveRecommendationResponseDto>(statusResult.Value);
        Assert.Equal("APPROVED", data.Decision);
        Assert.NotNull(data.WorkOrder);
    }

    [Fact]
    public async Task RejectRecommendation_ValidReason_Returns200Ok()
    {
        // ARRANGE
        var recId = Guid.NewGuid();
        var request = new RejectRecommendationRequest
        {
            Reason = "Specialty crew lacks necessary suction pumps",
            ExpectedRevision = 1
        };
        var rejectResponse = new RejectRecommendationResponseDto
        {
            RecommendationId = recId,
            Decision = "REJECTED",
            DecidedBy = _adminUserId,
            DecidedAt = DateTime.UtcNow,
            Reason = request.Reason
        };

        _mockDispatchService.Setup(s => s.RejectRecommendationAsync(recId, request, _adminUserId))
            .ReturnsAsync(rejectResponse);

        // ACT
        var result = await _controller.RejectRecommendation(recId, request);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<RejectRecommendationResponseDto>(okResult.Value);
        Assert.Equal("REJECTED", data.Decision);
    }

    [Fact]
    public async Task RegenerateRecommendation_ValidContext_Returns202Accepted()
    {
        // ARRANGE
        var recId = Guid.NewGuid();
        var request = new RegenerateRecommendationRequest
        {
            Reason = "Water level has receded; re-evaluate priority",
            ExpectedRevision = 1
        };
        var regenResponse = new RegenerateRecommendationResponseDto
        {
            JobId = Guid.NewGuid(),
            Status = "QUEUED",
            PreviousRecommendationId = recId,
            WorkflowId = Guid.NewGuid()
        };

        _mockDispatchService.Setup(s => s.RegenerateRecommendationAsync(recId, request, _adminUserId))
            .ReturnsAsync(regenResponse);

        // ACT
        var result = await _controller.RegenerateRecommendation(recId, request);

        // ASSERT
        var acceptedResult = Assert.IsType<AcceptedResult>(result);
        Assert.Equal(202, acceptedResult.StatusCode);

        var data = Assert.IsType<RegenerateRecommendationResponseDto>(acceptedResult.Value);
        Assert.Equal("QUEUED", data.Status);
    }
}
