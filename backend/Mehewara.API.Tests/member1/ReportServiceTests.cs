using Mehewara.API.Data;
using Mehewara.API.DTOs.Reports;
using Mehewara.API.Exceptions;
using Mehewara.API.Integrations.AiService;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Mehewara.API.Tests;

public class UnusedAiWorkflowClient : IAiWorkflowClient
{
    public Task<bool> TriggerWorkflowAsync(Report report, Guid workflowRunId)
        => throw new InvalidOperationException("The AI workflow client should not be invoked by these test paths.");
}

public class UnusedServiceScopeFactory : IServiceScopeFactory
{
    public IServiceScope CreateScope() => throw new InvalidOperationException("No background scope should be created by these test paths.");
}

public class ReportServiceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ReportService _service;
    private readonly Guid _residentId = Guid.NewGuid();
    private readonly Guid _otherResidentId = Guid.NewGuid();

    public ReportServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        var role = new Role { RoleId = Guid.NewGuid(), RoleCode = "RESIDENT", RoleName = "Resident", IsActive = true };
        _context.Roles.Add(role);
        _context.Users.Add(new User
        {
            UserId = _residentId,
            RoleId = role.RoleId,
            Role = role,
            FirstName = "Kamal",
            LastName = "Perera",
            Email = "kamal@example.com",
            PasswordHash = "hash",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        });
        _context.Users.Add(new User
        {
            UserId = _otherResidentId,
            RoleId = role.RoleId,
            Role = role,
            FirstName = "Nimal",
            LastName = "Silva",
            Email = "nimal@example.com",
            PasswordHash = "hash",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        });
        _context.SaveChanges();

        _service = new ReportService(
            _context,
            new UnusedPhotoStorageService(),
            new UnusedAiWorkflowClient(),
            new UnusedServiceScopeFactory(),
            NullLogger<ReportService>.Instance);
    }

    public void Dispose() => _context.Dispose();

    private static CreateReportRequest ValidRequest() => new()
    {
        Description = "Deep pothole damaging vehicles near the bus stand",
        Category = "ROAD",
        Latitude = 6.9271m,
        Longitude = 79.8612m,
        Address = "Main Street",
    };

    [Fact]
    public async Task CreateReportAsync_WithUnsupportedCategory_ThrowsValidationException()
    {
        var request = ValidRequest();
        request.Category = "UNKNOWN_CATEGORY";

        await Assert.ThrowsAsync<ValidationException>(() => _service.CreateReportAsync(_residentId, request));
    }

    [Theory]
    [InlineData(-91)]
    [InlineData(91)]
    public async Task CreateReportAsync_WithLatitudeOutOfRange_ThrowsValidationException(decimal latitude)
    {
        var request = ValidRequest();
        request.Latitude = latitude;

        await Assert.ThrowsAsync<ValidationException>(() => _service.CreateReportAsync(_residentId, request));
    }

    [Theory]
    [InlineData(-181)]
    [InlineData(181)]
    public async Task CreateReportAsync_WithLongitudeOutOfRange_ThrowsValidationException(decimal longitude)
    {
        var request = ValidRequest();
        request.Longitude = longitude;

        await Assert.ThrowsAsync<ValidationException>(() => _service.CreateReportAsync(_residentId, request));
    }

    [Fact]
    public async Task CreateReportAsync_WithUnknownResident_ThrowsNotFoundException()
    {
        await Assert.ThrowsAsync<NotFoundException>(() => _service.CreateReportAsync(Guid.NewGuid(), ValidRequest()));
    }

    private async Task<Report> SeedReportAsync(Guid residentId, string status = "PENDING")
    {
        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = residentId,
            Description = "Deep pothole damaging vehicles near the bus stand",
            Category = "ROAD",
            Latitude = 6.9271m,
            Longitude = 79.8612m,
            Address = "Main Street",
            Status = status,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        _context.Reports.Add(report);
        await _context.SaveChangesAsync();
        return report;
    }

    [Fact]
    public async Task GetReportByIdAsync_WhenOwnedByRequester_ReturnsReport()
    {
        var report = await SeedReportAsync(_residentId);

        var result = await _service.GetReportByIdAsync(report.ReportId, _residentId, "RESIDENT");

        Assert.Equal(report.ReportId, result.Id);
    }

    [Fact]
    public async Task GetReportByIdAsync_WhenNotOwnedAndNotAdmin_ThrowsForbiddenException()
    {
        var report = await SeedReportAsync(_otherResidentId);

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.GetReportByIdAsync(report.ReportId, _residentId, "RESIDENT"));
    }

    [Fact]
    public async Task GetReportByIdAsync_WhenAdmin_CanViewAnyResidentsReport()
    {
        var report = await SeedReportAsync(_otherResidentId);

        var result = await _service.GetReportByIdAsync(report.ReportId, _residentId, "ADMIN");

        Assert.Equal(report.ReportId, result.Id);
    }

    [Fact]
    public async Task GetReportByIdAsync_WithUnknownReportId_ThrowsNotFoundException()
    {
        await Assert.ThrowsAsync<NotFoundException>(() =>
            _service.GetReportByIdAsync(Guid.NewGuid(), _residentId, "RESIDENT"));
    }

    [Fact]
    public async Task GetResidentReportsAsync_OnlyReturnsReportsBelongingToThatResident()
    {
        await SeedReportAsync(_residentId);
        await SeedReportAsync(_otherResidentId);

        var result = await _service.GetResidentReportsAsync(_residentId, page: 1, pageSize: 20, status: null, sortBy: null, sortDirection: null);

        Assert.Single(result.Items);
    }

    [Fact]
    public async Task GetResidentReportsAsync_FiltersByStatusCaseInsensitively()
    {
        await SeedReportAsync(_residentId, status: "RESOLVED");
        await SeedReportAsync(_residentId, status: "PENDING");

        var result = await _service.GetResidentReportsAsync(_residentId, page: 1, pageSize: 20, status: "resolved", sortBy: null, sortDirection: null);

        Assert.Single(result.Items);
        Assert.Equal("RESOLVED", result.Items[0].Status);
    }

    [Fact]
    public async Task GetResidentReportsAsync_DefaultsToInvalidPageAndPageSizeFallbacks()
    {
        await SeedReportAsync(_residentId);

        var result = await _service.GetResidentReportsAsync(_residentId, page: 0, pageSize: 0, status: null, sortBy: null, sortDirection: null);

        Assert.Equal(1, result.Page);
        Assert.Equal(20, result.PageSize);
    }
}
