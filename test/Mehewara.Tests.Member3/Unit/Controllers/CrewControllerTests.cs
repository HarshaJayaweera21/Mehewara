using Mehewara.API.Controllers;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Controllers;

public class CrewControllerTests
{
    private readonly Mock<ICrewService> _mockCrewService;
    private readonly CrewController _controller;

    public CrewControllerTests()
    {
        _mockCrewService = new Mock<ICrewService>();
        _controller = new CrewController(_mockCrewService.Object);
    }

    [Fact]
    public async Task GetCrews_ReturnsOkWithPagedResult()
    {
        // ARRANGE
        var query = new CrewQueryParams { Page = 1, PageSize = 10 };
        var pagedResult = new PagedResult<CrewListItemDto>
        {
            Items = new List<CrewListItemDto>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    Name = "Drainage Alpha",
                    CrewType = "DRAINAGE",
                    Status = "AVAILABLE",
                    CrewLeaderUserId = Guid.NewGuid()
                }
            },
            TotalItems = 1,
            Page = 1,
            PageSize = 10,
            SortBy = "createdAt",
            SortDirection = "desc"
        };

        _mockCrewService.Setup(s => s.GetCrewsAsync(query))
            .ReturnsAsync(pagedResult);

        // ACT
        var result = await _controller.GetCrews(query);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<PagedResult<CrewListItemDto>>(okResult.Value);
        Assert.Single(data.Items);
        Assert.Equal("Drainage Alpha", data.Items[0].Name);
    }

    [Fact]
    public async Task GetCrews_WithFilters_PassesFiltersToService()
    {
        // ARRANGE
        var query = new CrewQueryParams { CrewType = "ROAD", Status = "BUSY", Page = 1, PageSize = 20 };
        _mockCrewService.Setup(s => s.GetCrewsAsync(query))
            .ReturnsAsync(new PagedResult<CrewListItemDto> { Items = new List<CrewListItemDto>() });

        // ACT
        var result = await _controller.GetCrews(query);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        _mockCrewService.Verify(s => s.GetCrewsAsync(It.Is<CrewQueryParams>(q => q.CrewType == "ROAD" && q.Status == "BUSY")), Times.Once);
    }

    [Fact]
    public async Task GetAvailability_ReturnsOkWithAvailabilityList()
    {
        // ARRANGE
        var availability = new List<CrewAvailabilityDto>
        {
            new() { CrewId = Guid.NewGuid(), Name = "Electrical Delta", CrewType = "ELECTRICAL", Status = "AVAILABLE", ActiveWorkOrderId = null }
        };

        _mockCrewService.Setup(s => s.GetAvailableCrewsAsync("ELECTRICAL", "AVAILABLE"))
            .ReturnsAsync(availability);

        // ACT
        var result = await _controller.GetAvailability("ELECTRICAL", "AVAILABLE");

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<CrewAvailabilityResponseDto>(okResult.Value);
        Assert.Single(data.Items);
        Assert.Equal("Electrical Delta", data.Items[0].Name);
    }

    [Fact]
    public async Task GetCrewById_ExistingCrew_ReturnsOkWithDetails()
    {
        // ARRANGE
        var crewId = Guid.NewGuid();
        var detail = new CrewDetailDto
        {
            Id = crewId,
            Name = "Road Maintenance Bravo",
            CrewType = "ROAD",
            Status = "AVAILABLE",
            Description = "Responsible for arterial road paving",
            ContactNumber = "+94112345678"
        };

        _mockCrewService.Setup(s => s.GetCrewByIdAsync(crewId))
            .ReturnsAsync(detail);

        // ACT
        var result = await _controller.GetCrewById(crewId);

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var returnedCrew = Assert.IsType<CrewDetailDto>(okResult.Value);
        Assert.Equal(crewId, returnedCrew.Id);
        Assert.Equal("Road Maintenance Bravo", returnedCrew.Name);
    }

    [Fact]
    public async Task GetCrewById_NonExistentCrew_ThrowsNotFoundException()
    {
        // ARRANGE
        var missingId = Guid.NewGuid();
        _mockCrewService.Setup(s => s.GetCrewByIdAsync(missingId))
            .ReturnsAsync((CrewDetailDto?)null);

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<NotFoundException>(() => _controller.GetCrewById(missingId));
        Assert.Equal("CREW_NOT_FOUND", ex.ErrorCode);
    }
}
