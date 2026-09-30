using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems.Consolidation;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Mehewara.Tests.Member2.Unit.Services;

public class ProblemConsolidationServiceTests
{
    private static AppDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    // TEST 1: Rejects Invalid Decision Enum

    [Fact]
    public async Task ApplyConsolidationAsync_InvalidDecision_ReturnsFailedValidation()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var logger = NullLogger<ProblemConsolidationService>.Instance;
        var service = new ProblemConsolidationService(context, logger);

        var consolidation = new ProblemConsolidationResultDto
        {
            ReportId = Guid.NewGuid(),
            Decision = "HALLUCINATED_DECISION" // Not in allowed enum
        };

        // 2. ACT
        var outcome = await service.ApplyConsolidationAsync(consolidation);

        // 3. ASSERT
        Assert.False(outcome.Success);
        Assert.Equal("FAILED", outcome.ValidationStatus);
        Assert.Contains(outcome.ValidationErrors, e => e.Contains("Invalid decision"));
    }

    // TEST 2: Conflict Guard (Report already linked to another problem)

    [Fact]
    public async Task ApplyConsolidationAsync_ReportAlreadyAssigned_BlocksOverwriting()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var logger = NullLogger<ProblemConsolidationService>.Instance;
        var service = new ProblemConsolidationService(context, logger);

        var existingProblemId = Guid.NewGuid();
        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ProblemId = existingProblemId, // Already linked
            Category = "ROAD",
            Latitude = 6.9m,
            Longitude = 79.8m,
            Status = "PROCESSING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        var consolidation = new ProblemConsolidationResultDto
        {
            ReportId = report.ReportId,
            Decision = "LINK_EXISTING",
            ProblemId = Guid.NewGuid() // Attempting to switch to a different problem
        };

        // 2. ACT
        var outcome = await service.ApplyConsolidationAsync(consolidation);

        // 3. ASSERT
        Assert.False(outcome.Success);
        Assert.Equal("FAILED", outcome.ValidationStatus);
        Assert.Contains(outcome.ValidationErrors, e => e.Contains("already assigned"));
    }

    
    // TEST 3: Safe Failure on UNCERTAIN (No DB changes)

    [Fact]
    public async Task ApplyConsolidationAsync_UncertainDecision_ReturnsSafeFailureWithoutDbMutation()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var logger = NullLogger<ProblemConsolidationService>.Instance;
        var service = new ProblemConsolidationService(context, logger);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ProblemId = null,
            Category = "DRAINAGE",
            Latitude = 6.9m,
            Longitude = 79.8m,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        var consolidation = new ProblemConsolidationResultDto
        {
            ReportId = report.ReportId,
            Decision = "UNCERTAIN",
            Summary = "Borderline distance between two culverts"
        };

        // 2. ACT
        var outcome = await service.ApplyConsolidationAsync(consolidation);

        // 3. ASSERT
        Assert.True(outcome.Success);
        Assert.Equal("SAFE_FAILURE", outcome.ValidationStatus);
        Assert.Null(outcome.ProblemId);

        // Verify DB was NOT mutated
        var unchangedReport = await context.Reports.FindAsync(report.ReportId);
        Assert.NotNull(unchangedReport);
        Assert.Null(unchangedReport.ProblemId);
        Assert.Equal("PENDING", unchangedReport.Status);
    }


    // TEST 4: CREATE_NEW Valid Candidate (Creates Problem & Prepares Agent 3 Handoff)

    [Fact]
    public async Task ApplyConsolidationAsync_ValidCreateNew_CreatesProblemAndAssemblesProblemContext()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var logger = NullLogger<ProblemConsolidationService>.Instance;
        var service = new ProblemConsolidationService(context, logger);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            Category = "ROAD",
            Latitude = 6.9200m,
            Longitude = 79.8600m,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        var consolidation = new ProblemConsolidationResultDto
        {
            ReportId = report.ReportId,
            Decision = "CREATE_NEW",
            Summary = "Severe subsidence on main carriage lane",
            NewProblem = new NewProblemCandidateDto
            {
                Title = "Road Subsidence near Junction",
                Description = "Carriage lane sinking",
                Category = "ROAD",
                Latitude = 6.9200m,
                Longitude = 79.8600m,
                Address = "Baseline Rd Junction"
            }
        };

        // 2. ACT
        var outcome = await service.ApplyConsolidationAsync(consolidation);

        // 3. ASSERT
        Assert.True(outcome.Success);
        Assert.Equal("PASSED", outcome.ValidationStatus);
        Assert.NotNull(outcome.ProblemId);

        // Verify Problem created in DB
        var problem = await context.Problems.FindAsync(outcome.ProblemId);
        Assert.NotNull(problem);
        Assert.Equal("Road Subsidence near Junction", problem.Title);
        Assert.Equal("ROAD", problem.Category);
        Assert.Equal("IDENTIFIED", problem.Status);

        // Verify Report linked
        var updatedReport = await context.Reports.FindAsync(report.ReportId);
        Assert.NotNull(updatedReport);
        Assert.Equal(outcome.ProblemId, updatedReport.ProblemId);

        // Verify ProblemContext handoff assembled for Agent 3
        Assert.NotNull(outcome.ProblemContext);
        Assert.Equal(outcome.ProblemId, outcome.ProblemContext.ProblemId);
        Assert.Equal("Road Subsidence near Junction", outcome.ProblemContext.Title);
        Assert.Equal("Severe subsidence on main carriage lane", outcome.ProblemContext.ConsolidationSummary);
    }


    // TEST 5: CREATE_NEW Invalid Candidate (Deterministic Validation Fails)

    [Fact]
    public async Task ApplyConsolidationAsync_InvalidCoordinatesAndCategory_FailsValidation()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var logger = NullLogger<ProblemConsolidationService>.Instance;
        var service = new ProblemConsolidationService(context, logger);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            Category = "ROAD",
            Latitude = 6.9m,
            Longitude = 79.8m,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        var consolidation = new ProblemConsolidationResultDto
        {
            ReportId = report.ReportId,
            Decision = "CREATE_NEW",
            NewProblem = new NewProblemCandidateDto
            {
                Title = "Test problem",
                Category = "INVALID_CATEGORY", // Not in allowed categories
                Latitude = 95.0m,               // Exceeds +90 degree latitude limit
                Longitude = 79.8m
            }
        };

        // 2. ACT
        var outcome = await service.ApplyConsolidationAsync(consolidation);

        // 3. ASSERT
        Assert.False(outcome.Success);
        Assert.Equal("FAILED", outcome.ValidationStatus);
        Assert.Contains(outcome.ValidationErrors, e => e.Contains("Invalid category"));
        Assert.Contains(outcome.ValidationErrors, e => e.Contains("Latitude must be between"));
    }
}
