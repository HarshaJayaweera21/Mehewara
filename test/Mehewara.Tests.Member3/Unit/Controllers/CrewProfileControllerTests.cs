using System.Security.Claims;
using Mehewara.API.Controllers;
using Mehewara.API.DTOs.Common;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Exceptions;
using Mehewara.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Controllers;

public class CrewProfileControllerTests
{
    private readonly Mock<ICrewService> _mockCrewService;
    private readonly Mock<ICrewLocationService> _mockLocationService;
    private readonly CrewProfileController _controller;
    private readonly Guid _testUserId = Guid.NewGuid();

    public CrewProfileControllerTests()
    {
        _mockCrewService = new Mock<ICrewService>();
        _mockLocationService = new Mock<ICrewLocationService>();
        _controller = new CrewProfileController(
            _mockCrewService.Object,
            _mockLocationService.Object,
            NullLogger<CrewProfileController>.Instance);

        SetUserContext(_testUserId, "CREW_LEADER_DRAINAGE");
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

        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = principal }
        };
    }

    [Fact]
    public async Task GetMyCrewProfile_ValidLeader_ReturnsOkWithProfile()
    {
        // ARRANGE
        var crewDetail = new CrewDetailDto
        {
            Id = Guid.NewGuid(),
            Name = "Drainage Rapid Response Unit Alpha",
            CrewType = "DRAINAGE",
            Status = "AVAILABLE",
            CrewLeaderUserId = _testUserId,
            CrewLeaderName = "Sunil Perera"
        };

        _mockCrewService.Setup(s => s.GetCrewByLeaderUserIdAsync(_testUserId))
            .ReturnsAsync(crewDetail);

        // ACT
        var result = await _controller.GetMyCrewProfile();

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<CrewDetailDto>(okResult.Value);
        Assert.Equal(crewDetail.Id, data.Id);
        Assert.Equal("Drainage Rapid Response Unit Alpha", data.Name);
    }

    [Fact]
    public async Task GetMyCrewProfile_UnlinkedLeader_ThrowsNotFoundException()
    {
        // ARRANGE
        _mockCrewService.Setup(s => s.GetCrewByLeaderUserIdAsync(_testUserId))
            .ReturnsAsync((CrewDetailDto?)null);

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<NotFoundException>(() => _controller.GetMyCrewProfile());
        Assert.Equal("CREW_PROFILE_NOT_FOUND", ex.ErrorCode);
    }

    [Fact]
    public async Task UpdateMyCrewStatus_ValidToggle_ReturnsOkWithUpdatedCrew()
    {
        // ARRANGE
        var crewId = Guid.NewGuid();
        var existingCrew = new CrewDetailDto
        {
            Id = crewId,
            Name = "Drainage Alpha",
            CrewType = "DRAINAGE",
            Status = "AVAILABLE",
            CrewLeaderUserId = _testUserId
        };
        var updatedCrew = new CrewDetailDto
        {
            Id = crewId,
            Name = "Drainage Alpha",
            CrewType = "DRAINAGE",
            Status = "UNAVAILABLE",
            CrewLeaderUserId = _testUserId
        };

        _mockCrewService.Setup(s => s.GetCrewByLeaderUserIdAsync(_testUserId))
            .ReturnsAsync(existingCrew);
        _mockCrewService.Setup(s => s.UpdateCrewStatusAsync(crewId, "UNAVAILABLE"))
            .ReturnsAsync(updatedCrew);

        // ACT
        var result = await _controller.UpdateMyCrewStatus(new UpdateCrewStatusRequestDto { Status = "UNAVAILABLE" });

        // ASSERT
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var data = Assert.IsType<CrewDetailDto>(okResult.Value);
        Assert.Equal("UNAVAILABLE", data.Status);
    }

    [Fact]
    public async Task UpdateMyCrewStatus_WhenServiceThrowsConflict_PropagatesException()
    {
        // ARRANGE
        var crewId = Guid.NewGuid();
        var existingCrew = new CrewDetailDto
        {
            Id = crewId,
            Name = "Drainage Alpha",
            Status = "AVAILABLE",
            CrewLeaderUserId = _testUserId
        };

        _mockCrewService.Setup(s => s.GetCrewByLeaderUserIdAsync(_testUserId))
            .ReturnsAsync(existingCrew);
        _mockCrewService.Setup(s => s.UpdateCrewStatusAsync(crewId, "UNAVAILABLE"))
            .ThrowsAsync(new ConflictException("Cannot mark crew UNAVAILABLE while active work order is assigned.", "ACTIVE_WORK_ORDER_EXISTS"));

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<ConflictException>(() =>
            _controller.UpdateMyCrewStatus(new UpdateCrewStatusRequestDto { Status = "UNAVAILABLE" }));
        Assert.Equal("ACTIVE_WORK_ORDER_EXISTS", ex.ErrorCode);
    }

    [Fact]
    public async Task RecordHeartbeat_ValidCoordinates_RecordsInLocationServiceAndReturnsNoContent()
    {
        // ARRANGE
        var crewId = Guid.NewGuid();
        var existingCrew = new CrewDetailDto { Id = crewId, CrewLeaderUserId = _testUserId };

        _mockCrewService.Setup(s => s.GetCrewByLeaderUserIdAsync(_testUserId))
            .ReturnsAsync(existingCrew);

        var heartbeat = new CrewHeartbeatDto { Latitude = 6.9271m, Longitude = 79.8612m };

        // ACT
        var result = await _controller.RecordHeartbeat(heartbeat);

        // ASSERT
        Assert.IsType<NoContentResult>(result);
        _mockLocationService.Verify(s => s.RecordHeartbeat(crewId, 6.9271m, 79.8612m), Times.Once);
    }

    [Fact]
    public async Task RecordHeartbeat_InvalidCoordinates_ThrowsBadRequestException()
    {
        // ARRANGE
        var invalidHeartbeat = new CrewHeartbeatDto { Latitude = 120.0m, Longitude = 79.8612m };

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<BadRequestException>(() => _controller.RecordHeartbeat(invalidHeartbeat));
        Assert.Equal("INVALID_COORDINATES", ex.ErrorCode);
    }
}
