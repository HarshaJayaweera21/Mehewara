using System.Security.Claims;
using Mehewara.API.Controllers;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Controllers;

public class WorkOrdersControllerTests
{
    private readonly Mock<IWorkOrderService> _mockOrdersService;
    private readonly AppDbContext _dbContext;
    private readonly WorkOrdersController _controller;
    private readonly CrewWorkOrdersController _crewOrdersController;
    private readonly Guid _userId = Guid.NewGuid();

    public WorkOrdersControllerTests()
    {
        _mockOrdersService = new Mock<IWorkOrderService>();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _dbContext = new AppDbContext(options);

        _controller = new WorkOrdersController(_mockOrdersService.Object, _dbContext, NullLogger<WorkOrdersController>.Instance);
        _crewOrdersController = new CrewWorkOrdersController(_mockOrdersService.Object);

        SetUserContext(_userId, "ADMIN");
    }

    private void SetUserContext(Guid userId, string role)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, role)
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        _controller.ControllerContext = new ControllerContext { HttpContext = httpContext };
        _crewOrdersController.ControllerContext = new ControllerContext { HttpContext = httpContext };
    }

    [Fact]
    public async Task List_Admin_ReturnsOkWithPagedResult()
    {
        // ARRANGE
        var query = new WorkOrderQuery { Page = 1, PageSize = 10 };
        var paged = new PagedResult<WorkOrderDto>
        {
            Items = new List<WorkOrderDto>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    Title = "Clear storm drain",
                    Status = "ASSIGNED",
                    Priority = "HIGH",
                    CrewName = "Drainage Alpha"
                }
            },
            TotalItems = 1,
            Page = 1,
            PageSize = 10
        };

        _mockOrdersService.Setup(s => s.GetAdminOrdersAsync(query))
            .ReturnsAsync(paged);

        // ACT
        var result = await _controller.List(query);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<PagedResult<WorkOrderDto>>(okResult.Value);
        Assert.Single(data.Items);
        Assert.Equal("Clear storm drain", data.Items[0].Title);
    }

    [Fact]
    public async Task Detail_Existing_ReturnsOkWithWorkOrder()
    {
        // ARRANGE
        var orderId = Guid.NewGuid();
        var dto = new WorkOrderDto
        {
            Id = orderId,
            Title = "Asphalt pothole repair",
            Status = "IN_PROGRESS",
            Priority = "MEDIUM"
        };

        _mockOrdersService.Setup(s => s.GetOrderAsync(orderId, _userId, true))
            .ReturnsAsync(dto);

        // ACT
        var result = await _controller.Detail(orderId);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<WorkOrderDto>(okResult.Value);
        Assert.Equal(orderId, data.Id);
    }

    [Fact]
    public async Task Start_CrewLeader_ReturnsOkWithStartedOrder()
    {
        // ARRANGE
        SetUserContext(_userId, "CREW_LEADER_DRAINAGE");
        var orderId = Guid.NewGuid();
        var startedDto = new WorkOrderDto { Id = orderId, Status = "IN_PROGRESS" };

        _mockOrdersService.Setup(s => s.StartAsync(orderId, _userId))
            .ReturnsAsync(startedDto);

        // ACT
        var result = await _controller.Start(orderId);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<WorkOrderDto>(okResult.Value);
        Assert.Equal("IN_PROGRESS", data.Status);
    }

    [Fact]
    public async Task Complete_CrewLeader_ReturnsOkWithCompletedOrder()
    {
        // ARRANGE
        SetUserContext(_userId, "CREW_LEADER_ROAD");
        var orderId = Guid.NewGuid();
        var request = new CompleteWorkOrderRequest { CompletionNotes = "Debris cleared and asphalt repaved." };
        var completedDto = new WorkOrderDto
        {
            Id = orderId,
            Status = "COMPLETED",
            CompletionNotes = request.CompletionNotes
        };

        _mockOrdersService.Setup(s => s.CompleteAsync(orderId, _userId, request))
            .ReturnsAsync(completedDto);

        // ACT
        var result = await _controller.Complete(orderId, request);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<WorkOrderDto>(okResult.Value);
        Assert.Equal("COMPLETED", data.Status);
        Assert.Equal(request.CompletionNotes, data.CompletionNotes);
    }

    [Fact]
    public async Task CrewWorkOrdersController_List_CallsGetCrewOrdersAsync()
    {
        // ARRANGE
        SetUserContext(_userId, "CREW_LEADER_DRAINAGE");
        var query = new WorkOrderQuery { Status = "ASSIGNED" };
        var paged = new PagedResult<WorkOrderDto> { Items = new List<WorkOrderDto>() };

        _mockOrdersService.Setup(s => s.GetCrewOrdersAsync(query, _userId))
            .ReturnsAsync(paged);

        // ACT
        var result = await _crewOrdersController.List(query);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        _mockOrdersService.Verify(s => s.GetCrewOrdersAsync(query, _userId), Times.Once);
    }
}
