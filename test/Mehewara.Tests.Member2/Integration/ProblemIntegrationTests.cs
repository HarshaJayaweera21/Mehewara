using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems.Consolidation;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Mehewara.Tests.Member2.Integration;

public class ProblemIntegrationTests
{
    private static AppDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    [Fact]
    public async Task CompleteWorkflow_AutonomousConsolidation_And_CoordinatorUncertainTriage()
    {
        using var context = CreateInMemoryDbContext();
        var consolidationService = new ProblemConsolidationService(context, NullLogger<ProblemConsolidationService>.Instance);
        var problemService = new ProblemService(context);

        // Seed resident
        var resident = new User
        {
            UserId = Guid.NewGuid(),
            FirstName = "Sunil",
            LastName = "Perera",
            Email = "sunil@example.com",
            PasswordHash = "hashed",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Users.Add(resident);

        
        // PHASE 1: Agent 2 Autonomous CREATE_NEW for Report 1
        
        var report1 = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            Description = "Severe drain flooding blocking road entrance",
            Category = "DRAINAGE",
            Latitude = 6.9000m,
            Longitude = 79.8000m,
            Address = "Galle Road Gate 1",
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report1);
        await context.SaveChangesAsync();

        var aiCreateOutcome = await consolidationService.ApplyConsolidationAsync(new ProblemConsolidationResultDto
        {
            ReportId = report1.ReportId,
            Decision = "CREATE_NEW",
            Summary = "Drainage obstruction causing roadway flood",
            NewProblem = new NewProblemCandidateDto
            {
                Title = "Galle Road Drainage Flooding",
                Description = "Culvert overflow",
                Category = "DRAINAGE",
                Latitude = 6.9000m,
                Longitude = 79.8000m,
                Address = "Galle Road Gate 1"
            }
        });

        Assert.True(aiCreateOutcome.Success);
        var problemId = aiCreateOutcome.ProblemId!.Value;

        
        // PHASE 2: Agent 2 Autonomous LINK_EXISTING for Report 2
        
        var report2 = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            Description = "Water leaking from same culvert near gate 1",
            Category = "DRAINAGE",
            Latitude = 6.9002m,
            Longitude = 79.8001m,
            Address = "Galle Road Gate 1",
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report2);
        await context.SaveChangesAsync();

        var aiLinkOutcome = await consolidationService.ApplyConsolidationAsync(new ProblemConsolidationResultDto
        {
            ReportId = report2.ReportId,
            Decision = "LINK_EXISTING",
            ProblemId = problemId,
            Summary = "Duplicate flooding report at exact same culvert"
        });

        Assert.True(aiLinkOutcome.Success);
        Assert.Equal(problemId, aiLinkOutcome.ProblemId);

        // Verify Report 2 is linked autonomously
        var dbReport2 = await context.Reports.FindAsync(report2.ReportId);
        Assert.Equal(problemId, dbReport2!.ProblemId);

        
        // PHASE 3: Agent 2 flags Report 3 as UNCERTAIN
        // Borderline distance / unclear boundary -> Safe Failure to Triage
        
        var report3 = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            Description = "Water puddles outside shop, unclear if related to culvert",
            Category = "DRAINAGE",
            Latitude = 6.9080m,
            Longitude = 79.8080m,
            Address = "Galle Road 300m North",
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report3);
        await context.SaveChangesAsync();

        var aiUncertainOutcome = await consolidationService.ApplyConsolidationAsync(new ProblemConsolidationResultDto
        {
            ReportId = report3.ReportId,
            Decision = "UNCERTAIN",
            Summary = "Borderline distance (350m) and vague description. Flagged for coordinator."
        });

        Assert.True(aiUncertainOutcome.Success);
        Assert.Equal("SAFE_FAILURE", aiUncertainOutcome.ValidationStatus);
        Assert.Null(aiUncertainOutcome.ProblemId); // Left unassigned!

        
        // PHASE 4: Coordinator Triage & Manual Linking
        
        // 1. Coordinator checks triage queue
        var triageQueue = await problemService.GetUncertainReportsAsync();
        Assert.Contains(triageQueue, r => r.ReportId == report3.ReportId);

        // 2. Coordinator makes manual link decision with notes
        var coordinatorLinkResult = await problemService.LinkUncertainReportAsync(new LinkUncertainReportRequest
        {
            ReportId = report3.ReportId,
            ProblemId = problemId,
            CoordinatorNotes = "Confirmed runoff originates from the same culvert."
        });

        
        // PHASE 5: Final Validation of the Municipal Problem
        
        var finalProblem = await problemService.GetProblemByIdAsync(problemId);

        // All 3 reports now linked (2 by AI, 1 by Coordinator)
        Assert.Equal(3, finalProblem.RelatedReports.Count);

        // Centroid coordinates updated
        Assert.NotEqual(0m, finalProblem.Latitude);
        Assert.NotEqual(0m, finalProblem.Longitude);

        // Coordinator note preserved in description
        Assert.Contains("Confirmed runoff originates from the same culvert.", finalProblem.Description);
    }
}