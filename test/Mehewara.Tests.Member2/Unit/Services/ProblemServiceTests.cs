using Mehewara.API.Data;
using Mehewara.API.DTOs.Problems;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Mehewara.API.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Mehewara.Tests.Member2.Unit.Services;

public class ProblemServiceTests
{
    /// <summary>
    /// Helper method: Creates a fresh, isolated in-memory AppDbContext for each test.
    /// A unique database name ensures tests never share or pollute each other's data.
    /// </summary>
    private static AppDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    // TEST 1: CreateProblemAsync

    [Fact]
    public async Task CreateProblemAsync_ValidRequest_ShouldCreateProblemWithIdentifiedStatus()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        var request = new CreateProblemRequest
        {
            Title = "Severe Road Flooding",
            Description = "Road impassable due to blocked culvert",
            Category = "DRAINAGE",
            Latitude = 6.9271m,
            Longitude = 79.8612m,
            Address = "Baseline Road, Dematagoda"
        };

        // 2. ACT
        var result = await service.CreateProblemAsync(request);

        // 3. ASSERT
        // Verify return object
        Assert.NotNull(result);
        Assert.NotEqual(Guid.Empty, result.Id);
        Assert.Equal("Severe Road Flooding", result.Title);
        Assert.Equal("DRAINAGE", result.Category);
        Assert.Equal(6.9271m, result.Latitude);
        Assert.Equal(79.8612m, result.Longitude);
        Assert.Equal("Baseline Road, Dematagoda", result.Address);
        Assert.Equal("IDENTIFIED", result.Status); // Must default to IDENTIFIED per spec
        Assert.Equal(0, result.RelatedReportCount);

        // Verify database persistence
        var savedProblem = await context.Problems.FirstOrDefaultAsync(p => p.ProblemId == result.Id);
        Assert.NotNull(savedProblem);
        Assert.Equal("Severe Road Flooding", savedProblem.Title);
        Assert.Equal("IDENTIFIED", savedProblem.Status);
    }
    
        /// <summary>
    /// Helper: Seeds a test resident user for report ownership
    /// </summary>
    private static User CreateTestResident(AppDbContext context, string firstName = "Kamal", string lastName = "Perera")
    {
        var user = new User
        {
            UserId = Guid.NewGuid(),
            FirstName = firstName,
            LastName = lastName,
            Email = $"{firstName.ToLower()}.{Guid.NewGuid()}@example.com",
            PasswordHash = "hashed_pw",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Users.Add(user);
        return user;
    }

    
    // TEST 2: GetProblemByIdAsync
    

    [Fact]
    public async Task GetProblemByIdAsync_ExistingProblem_ReturnsDetailsWithRelatedReports()
    {
        // 1. ARRANGE: Seed 1 problem and 1 linked report in the DB
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var resident = CreateTestResident(context);

        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Large Pothole near Central College",
            Description = "Dangerous road crater.",
            Category = "ROAD",
            Latitude = 6.9271m,
            Longitude = 79.8612m,
            Address = "Central College Junction",
            Priority = "HIGH",
            PriorityScore = 75,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Problems.Add(problem);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            ProblemId = problem.ProblemId, // Link report to problem
            Description = "Deep pothole damaged my motorcycle tire",
            Category = "ROAD",
            Latitude = 6.9270m,
            Longitude = 79.8610m,
            Address = "Central College Junction",
            Status = "PROCESSING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        // 2. ACT
        var result = await service.GetProblemByIdAsync(problem.ProblemId);

        // 3. ASSERT
        Assert.NotNull(result);
        Assert.Equal(problem.ProblemId, result.Id);
        Assert.Equal("Large Pothole near Central College", result.Title);
        Assert.Equal("ROAD", result.Category);
        Assert.Equal("HIGH", result.Priority);
        Assert.Equal(75, result.PriorityScore);
        
        // Verify related reports navigation was loaded
        Assert.Single(result.RelatedReports);
        Assert.Equal(report.ReportId, result.RelatedReports[0].ReportId);
        Assert.Equal("Deep pothole damaged my motorcycle tire", result.RelatedReports[0].Description);
    }

    
    // TEST 3: GetProblemByIdAsync
    

    [Fact]
    public async Task GetProblemByIdAsync_NonExistingId_ThrowsNotFoundException()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var randomId = Guid.NewGuid();

        // 2. ACT & 3. ASSERT
        // Assert.ThrowsAsync expects the delegate to throw the specified exception
        var ex = await Assert.ThrowsAsync<NotFoundException>(() =>
            service.GetProblemByIdAsync(randomId));

        Assert.Equal("PROBLEM_NOT_FOUND", ex.ErrorCode);
    }

    
    // TEST 4: Category Filter

    [Fact]
    public async Task GetProblemsAsync_CategoryFilter_ReturnsOnlyMatchingCategory()
    {
        // 1. ARRANGE: Seed one DRAINAGE and one ROAD problem
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        context.Problems.AddRange(
            new Problem { 
                ProblemId = Guid.NewGuid(), 
                Title = "Drain blockage", 
                Category = "DRAINAGE", 
                Latitude = 6.9m, 
                Longitude = 79.8m, 
                Status = "IDENTIFIED", 
                CreatedAt = DateTime.UtcNow, 
                UpdatedAt = DateTime.UtcNow },

            new Problem { 
                ProblemId = Guid.NewGuid(), 
                Title = "Road crater", 
                Category = "ROAD", 
                Latitude = 6.9m, 
                Longitude = 79.8m, 
                Status = "IDENTIFIED", 
                CreatedAt = DateTime.UtcNow, 
                UpdatedAt = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        // 2. ACT: Filter by Category = "ROAD"
        var result = await service.GetProblemsAsync(new GetProblemsQuery { Category = "ROAD" });

        // 3. ASSERT: Assert.Single returns the single item in the collection
        var item = Assert.Single(result.Items);
        Assert.Equal("ROAD", item.Category);
        Assert.Equal("Road crater", item.Title);
    }

    
    // TEST 5: Status Filter

    [Fact]
    public async Task GetProblemsAsync_StatusFilter_ReturnsOnlyMatchingStatus()
    {
        // 1. ARRANGE: Seed one IDENTIFIED and one RESOLVED problem
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        context.Problems.AddRange(
            new Problem { ProblemId = Guid.NewGuid(), Title = "Active problem", Category = "ROAD", Latitude = 6.9m, Longitude = 79.8m, Status = "IDENTIFIED", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Problem { ProblemId = Guid.NewGuid(), Title = "Fixed problem", Category = "ROAD", Latitude = 6.9m, Longitude = 79.8m, Status = "RESOLVED", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        // 2. ACT: Filter by Status = "RESOLVED"
        var result = await service.GetProblemsAsync(new GetProblemsQuery { Status = "RESOLVED" });

        // 3. ASSERT
        var item = Assert.Single(result.Items);
        Assert.Equal("RESOLVED", item.Status);
        Assert.Equal("Fixed problem", item.Title);
    }

    
    // TEST 6: Search Filter (Title / Address)

    [Fact]
    public async Task GetProblemsAsync_SearchFilter_MatchesTitleOrAddress()
    {
        // 1. ARRANGE
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        context.Problems.AddRange(
            new Problem { ProblemId = Guid.NewGuid(), Title = "Streetlight failure", Address = "Galle Road, Colombo 03", Category = "ELECTRICAL", Latitude = 6.9m, Longitude = 79.8m, Status = "IDENTIFIED", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Problem { ProblemId = Guid.NewGuid(), Title = "Garbage dump", Address = "Kandy Road, Kelaniya", Category = "WASTE", Latitude = 6.9m, Longitude = 79.8m, Status = "IDENTIFIED", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        // 2. ACT: Search for "galle"
        var result = await service.GetProblemsAsync(new GetProblemsQuery { Search = "galle" });

        // 3. ASSERT
        var item = Assert.Single(result.Items);
        Assert.Equal("Streetlight failure", item.Title);
    }

    
    // TEST 7: Pagination Math

    [Fact]
    public async Task GetProblemsAsync_Pagination_ComputesCorrectPageAndTotalPages()
    {
        // 1. ARRANGE: Seed 5 problems
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        for (int i = 1; i <= 5; i++)
        {
            context.Problems.Add(new Problem
            {
                ProblemId = Guid.NewGuid(),
                Title = $"Problem #{i}",
                Category = "ROAD",
                Latitude = 6.9m,
                Longitude = 79.8m,
                Status = "IDENTIFIED",
                CreatedAt = DateTime.UtcNow.AddMinutes(i),
                UpdatedAt = DateTime.UtcNow
            });
        }
        await context.SaveChangesAsync();

        // 2. ACT: Request Page 1 with PageSize 2
        var result = await service.GetProblemsAsync(new GetProblemsQuery { Page = 1, PageSize = 2 });

        // 3. ASSERT: Math check using .Count()
        Assert.Equal(2, result.Items.Count());
        Assert.Equal(5, result.TotalItems);
        Assert.Equal(3, result.TotalPages);
        Assert.Equal(1, result.Page);
    }


    // TEST 8 & 9: GetReportsByProblemIdAsync

    [Fact]
    public async Task GetReportsByProblemIdAsync_ExistingProblem_ReturnsLinkedReports()
    {
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var resident = CreateTestResident(context, "Saman", "Kumara");

        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Collapsed Drain Wall",
            Category = "DRAINAGE",
            Latitude = 6.9000m,
            Longitude = 79.8500m,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Problems.Add(problem);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            ProblemId = problem.ProblemId,
            Description = "Water leaking from canal wall",
            Category = "DRAINAGE",
            Latitude = 6.9001m,
            Longitude = 79.8501m,
            Status = "PROCESSING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        var result = (await service.GetReportsByProblemIdAsync(problem.ProblemId)).ToList();

        Assert.Single(result);
        Assert.Equal(report.ReportId, result[0].Id);
        Assert.Equal("Saman Kumara", result[0].ResidentName);
    }

    [Fact]
    public async Task GetReportsByProblemIdAsync_NonExistingProblem_ThrowsNotFoundException()
    {
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);

        var ex = await Assert.ThrowsAsync<NotFoundException>(() =>
            service.GetReportsByProblemIdAsync(Guid.NewGuid()));

        Assert.Equal("PROBLEM_NOT_FOUND", ex.ErrorCode);
    }


    // TEST 10: Triage Queue & Haversine Proximity Calculation

    [Fact]
    public async Task GetUncertainReportsAsync_CalculatesNearbyCandidateProblemsWithin2Km()
    {
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var resident = CreateTestResident(context);

        // Unassigned uncertain report near Colombo Fort (6.9350, 79.8450)
        var uncertainReport = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            ProblemId = null, // null means unassigned / uncertain
            Description = "Water pipe bursting near clock tower",
            Category = "DRAINAGE",
            Latitude = 6.9350m,
            Longitude = 79.8450m,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(uncertainReport);

        // Candidate 1: ~400 meters away in Fort (Must be included)
        var nearbyProblem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Water main leakage Fort",
            Category = "DRAINAGE",
            Latitude = 6.9360m,
            Longitude = 79.8480m,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        // Candidate 2: ~115 km away in Kandy (Must be excluded > 2km)
        var farProblem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Kandy Road overflow",
            Category = "DRAINAGE",
            Latitude = 7.2906m,
            Longitude = 80.6337m,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        context.Problems.AddRange(nearbyProblem, farProblem);
        await context.SaveChangesAsync();

        var result = await service.GetUncertainReportsAsync();

        Assert.Single(result);
        var reportTriage = result[0];
        Assert.Equal(uncertainReport.ReportId, reportTriage.ReportId);

        // Verify proximity calculation: only the nearby Fort problem is returned
        Assert.Single(reportTriage.NearbyCandidates);
        Assert.Equal(nearbyProblem.ProblemId, reportTriage.NearbyCandidates[0].ProblemId);
        Assert.True(reportTriage.NearbyCandidates[0].DistanceMeters < 2000.0);
    }

    
    // TEST 11: LinkUncertainReportAsync (Arithmetic Centroid + Coordinator Notes)

    [Fact]
    public async Task LinkUncertainReportAsync_RecalculatesCentroidAndAppendsCoordinatorNotes()
    {
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var resident = CreateTestResident(context);

        // Existing Problem centered at (6.9000, 79.8000) based on Report 1
        var problem = new Problem
        {
            ProblemId = Guid.NewGuid(),
            Title = "Flooding near Junction",
            Description = "Initial flooding report.",
            Category = "DRAINAGE",
            Latitude = 6.9000m,
            Longitude = 79.8000m,
            Status = "IDENTIFIED",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Problems.Add(problem);

        var report1 = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            ProblemId = problem.ProblemId,
            Description = "Report 1 flooding",
            Category = "DRAINAGE",
            Latitude = 6.9000m,
            Longitude = 79.8000m,
            Status = "PROCESSING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report1);

        // Report 2 is unassigned at (6.9100, 79.8100)
        var report2 = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            ProblemId = null,
            Description = "Report 2 flooding further up",
            Category = "DRAINAGE",
            Latitude = 6.9100m,
            Longitude = 79.8100m,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report2);
        await context.SaveChangesAsync();

        var linkRequest = new Mehewara.API.DTOs.Problems.Consolidation.LinkUncertainReportRequest
        {
            ReportId = report2.ReportId,
            ProblemId = problem.ProblemId,
            CoordinatorNotes = "Confirmed identical incident via CCTV feed."
        };

        // ACT
        var response = await service.LinkUncertainReportAsync(linkRequest);

        // ASSERT
        Assert.NotNull(response);
        Assert.Equal(2, response.RelatedReportCount);

        // 1. Report 2 status becomes PROCESSING and linked to problem
        var updatedReport2 = await context.Reports.FindAsync(report2.ReportId);
        Assert.NotNull(updatedReport2);
        Assert.Equal(problem.ProblemId, updatedReport2.ProblemId);
        Assert.Equal("PROCESSING", updatedReport2.Status);

        // 2. Arithmetic Centroid Recalculation Check:
        // Average Lat: (6.9000 + 6.9100) / 2 = 6.9050
        // Average Lng: (79.8000 + 79.8100) / 2 = 79.8050
        var updatedProblem = await context.Problems.FindAsync(problem.ProblemId);
        Assert.NotNull(updatedProblem);
        Assert.Equal(6.9050m, updatedProblem.Latitude);
        Assert.Equal(79.8050m, updatedProblem.Longitude);

        // 3. Coordinator Notes appended
        Assert.Contains("[Coordinator Note]: Confirmed identical incident via CCTV feed.", updatedProblem.Description);

        // 4. Audit trail recorded in WorkflowEvents
        var auditEvent = await context.WorkflowEvents
            .FirstOrDefaultAsync(e => e.Stage == "PROBLEM_CONSOLIDATION");
        Assert.NotNull(auditEvent);
        Assert.Equal("Coordinator Manual Triage", auditEvent.AgentName);
        Assert.Contains("LINK_MANUAL", auditEvent.OutputData);
    }

    // TEST 12: CancelUncertainReportAsync (Spam/Duplicate Cancellation)

    [Fact]
    public async Task CancelUncertainReportAsync_ExistingReport_UpdatesStatusToCancelledAndLogsAudit()
    {
        using var context = CreateInMemoryDbContext();
        var service = new ProblemService(context);
        var resident = CreateTestResident(context);

        var report = new Report
        {
            ReportId = Guid.NewGuid(),
            ResidentId = resident.UserId,
            Description = "Prank report",
            Category = "WASTE",
            Latitude = 6.9m,
            Longitude = 79.8m,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Reports.Add(report);
        await context.SaveChangesAsync();

        await service.CancelUncertainReportAsync(report.ReportId, "Spam submission");

        var updatedReport = await context.Reports.FindAsync(report.ReportId);
        Assert.NotNull(updatedReport);
        Assert.Equal("CANCELLED", updatedReport.Status);

        var auditEvent = await context.WorkflowEvents
            .FirstOrDefaultAsync(e => e.Stage == "COMPLETED" && e.Status == "CANCELLED");
        Assert.NotNull(auditEvent);
        Assert.Contains("Spam submission", auditEvent.OutputData);
    }




}
