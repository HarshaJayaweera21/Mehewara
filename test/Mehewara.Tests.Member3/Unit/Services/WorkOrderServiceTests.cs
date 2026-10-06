using Mehewara.API.Data;
using Mehewara.API.DTOs.WorkOrders;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Mehewara.Tests.Member3.Unit.Services;

public class WorkOrderServiceTests
{
    private static AppDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    [Fact]
    public async Task GetAdminOrdersAsync_FilterByStatus_ReturnsMatchingOrders()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new WorkOrderService(context);

        var crew = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Drainage Alpha",
            CrewType = "DRAINAGE",
            Status = "BUSY",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Crews.Add(crew);

        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Culvert Flooding",
            Category = "DRAINAGE",
            Latitude = 6.9271m,
            Longitude = 79.8612m,
            Address = "Galle Road",
            Status = "ASSIGNED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Problems.Add(problem);

        var order1 = new WorkOrder
        {
            WorkOrderId = Guid.NewGuid(),
            CrewId = crew.CrewId,
            ProblemId = problem.ProblemId,
            Title = "Culvert unblocking",
            Priority = "HIGH",
            Status = "ASSIGNED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        var order2 = new WorkOrder
        {
            WorkOrderId = Guid.NewGuid(),
            CrewId = crew.CrewId,
            ProblemId = problem.ProblemId,
            Title = "Completed drain clearing",
            Priority = "MEDIUM",
            Status = "COMPLETED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.WorkOrders.AddRange(order1, order2);
        await context.SaveChangesAsync();

        // ACT
        var result = await service.GetAdminOrdersAsync(new WorkOrderQuery { Status = "ASSIGNED" });

        // ASSERT
        Assert.Single(result.Items);
        Assert.Equal("Culvert unblocking", result.Items[0].Title);
        Assert.Equal("ASSIGNED", result.Items[0].Status);
    }

    [Fact]
    public async Task GetOrderAsync_NonExistent_ThrowsNotFoundException()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new WorkOrderService(context);

        // ACT & ASSERT
        var ex = await Assert.ThrowsAsync<NotFoundException>(() =>
            service.GetOrderAsync(Guid.NewGuid(), Guid.NewGuid(), true));
        Assert.Equal("WORK_ORDER_NOT_FOUND", ex.ErrorCode);
    }

    [Fact]
    public async Task GetOrderAsync_BelongingToDifferentCrew_ThrowsForbiddenException()
    {
        // ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new WorkOrderService(context);

        var crew1LeaderUserId = Guid.NewGuid();
        var crew2LeaderUserId = Guid.NewGuid();

        var crew1 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Squad 1",
            CrewType = "DRAINAGE",
            Status = "AVAILABLE",
            CrewLeaderUserId = crew1LeaderUserId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        var crew2 = new Crew
        {
            CrewId = Guid.NewGuid(),
            CrewName = "Squad 2",
            CrewType = "ROAD",
            Status = "AVAILABLE",
            CrewLeaderUserId = crew2LeaderUserId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Crews.AddRange(crew1, crew2);

        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Drainage Job",
            Category = "DRAINAGE",
            Latitude = 6.9271m,
            Longitude = 79.8612m,
            Address = "Station Road",
            Status = "ASSIGNED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Problems.Add(problem);

        var order = new WorkOrder
        {
            WorkOrderId = Guid.NewGuid(),
            CrewId = crew1.CrewId,
            ProblemId = problem.ProblemId,
            Title = "Drainage Job",
            Status = "ASSIGNED",
            Priority = "HIGH",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.WorkOrders.Add(order);
        await context.SaveChangesAsync();

        // ACT & ASSERT (Crew 2 leader tries to access Crew 1 work order with isAdmin = false)
        var ex = await Assert.ThrowsAsync<ForbiddenException>(() =>
            service.GetOrderAsync(order.WorkOrderId, crew2LeaderUserId, false));
        Assert.Equal("WORK_ORDER_NOT_OWNED", ex.ErrorCode);
    }
}
