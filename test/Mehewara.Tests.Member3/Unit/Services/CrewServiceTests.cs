using Mehewara.API.Data;
using Mehewara.API.DTOs.Crew;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Services;

public class CrewServiceTests
{
    private static AppDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    [Fact]
    public async Task GetCrewsAsync_FilterByCrewType_ReturnsMatchingCrewsOnly()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        var crew1 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Drainage Alpha",
            CrewType = "DRAINAGE",
            Status = "AVAILABLE",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        var crew2 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Road Bravo",
            CrewType = "ROAD",
            Status = "AVAILABLE",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        context.Crews.AddRange(crew1, crew2);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.GetCrewsAsync(new CrewQueryParams { CrewType = "DRAINAGE" });

        // ASSERT
        Assert.Single(result.Items);
        Assert.Equal("Drainage Alpha", result.Items[0].Name);
        Assert.Equal("DRAINAGE", result.Items[0].CrewType);
    }

    [Fact]
    public async Task GetCrewsAsync_FilterByStatus_ReturnsMatchingCrewsOnly()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        var crew1 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Waste Charlie",
            CrewType = "WASTE",
            Status = "AVAILABLE",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        var crew2 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Electrical Delta",
            CrewType = "ELECTRICAL",
            Status = "BUSY",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        context.Crews.AddRange(crew1, crew2);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.GetCrewsAsync(new CrewQueryParams { Status = "BUSY" });

        // ASSERT
        Assert.Single(result.Items);
        Assert.Equal("Electrical Delta", result.Items[0].Name);
        Assert.Equal("BUSY", result.Items[0].Status);
    }

    [Fact]
    public async Task GetCrewByIdAsync_ExistingCrew_ReturnsDetailWithLeaderName()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        var role = new Role
        {
            RoleId = Guid.NewGuid(),
            RoleName = "Crew Leader Drainage",
            RoleCode = "CREW_LEADER_DRAINAGE",
            IsActive = true
        };
        context.Roles.Add(role);

        var leader = new User
        {
            UserId = Guid.NewGuid(),
            RoleId = role.RoleId,
            FirstName = "Sunil",
            LastName = "Perera",
            Email = "sunil@colombo.gov.lk",
            PasswordHash = "hash",
            Role = role,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Users.Add(leader);

        var crew = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Drainage Unit Alpha",
            CrewType = "DRAINAGE",
            Status = "AVAILABLE",
            CrewLeaderUserId = leader.UserId,
            Description = "Stormwater rapid response",
            ContactNumber = "+94112691111",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Crews.Add(crew);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.GetCrewByIdAsync(crew.CrewId);

        // ASSERT
        Assert.NotNull(result);
        Assert.Equal(crew.CrewId, result.Id);
        Assert.Equal("Drainage Unit Alpha", result.Name);
        Assert.Equal("Sunil Perera", result.CrewLeaderName);
    }

    [Fact]
    public async Task GetCrewByIdAsync_NonExistentCrew_ReturnsNull()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        // ACT
        var result = await service.GetCrewByIdAsync(Guid.NewGuid());

        // ASSERT
        Assert.Null(result);
    }

    [Fact]
    public async Task GetCrewByLeaderUserIdAsync_ResolvesCorrectCrew()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        var leaderUserId = Guid.NewGuid();
        var crew = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Environment Echo",
            CrewType = "ENVIRONMENT",
            Status = "AVAILABLE",
            CrewLeaderUserId = leaderUserId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Crews.Add(crew);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.GetCrewByLeaderUserIdAsync(leaderUserId);

        // ASSERT
        Assert.NotNull(result);
        Assert.Equal("Environment Echo", result.Name);
        Assert.Equal(leaderUserId, result.CrewLeaderUserId);
    }

    [Fact]
    public async Task UpdateCrewStatusAsync_TogglesAvailableToUnavailable()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        var crew = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Road Bravo",
            CrewType = "ROAD",
            Status = "AVAILABLE",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Crews.Add(crew);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.UpdateCrewStatusAsync(crew.CrewId, "UNAVAILABLE");

        // ASSERT
        Assert.Equal("UNAVAILABLE", result.Status);

        var dbCrew = await context.Crews.FindAsync(crew.CrewId);
        Assert.NotNull(dbCrew);
        Assert.Equal("UNAVAILABLE", dbCrew.Status);
    }

    [Fact]
    public async Task UpdateCrewStatusAsync_InvalidStatus_ThrowsValidationException()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new CrewService(context, NullLogger<CrewService>.Instance);

        // ACT & ASSERT
        await Assert.ThrowsAsync<ValidationException>(() =>
            service.UpdateCrewStatusAsync(Guid.NewGuid(), "ON_VACATION"));
    }
}
