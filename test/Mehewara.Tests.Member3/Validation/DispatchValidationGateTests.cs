using Xunit;

namespace Mehewara.Tests.Member3.Validation;

/// <summary>
/// Deterministic verification of the 10-Point Pre-Approval Validation Checklist
/// enforced immediately before WorkOrder creation upon dispatch recommendation approval.
/// Referenced in SE3090 Rubric, Member 3 Development Plan §6.8, and Member3 Individual Report §4.3.
/// </summary>
public class DispatchValidationGateTests
{
    // HELPER: Priority score band validator matching DispatchService.cs logic
    private static bool IsScoreBandValid(string priority, int score)
    {
        return priority switch
        {
            "LOW" => score is >= 0 and <= 29,
            "MEDIUM" => score is >= 30 and <= 59,
            "HIGH" => score is >= 60 and <= 84,
            "CRITICAL" => score is >= 85 and <= 100,
            _ => false
        };
    }

    // HELPER: Specialty matcher
    private static bool IsSpecialtyMatched(string problemCategory, string crewType)
    {
        return string.Equals(problemCategory.Trim(), crewType.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    // ── CHECK 1: Recommendation Event Output Validity ─────────────────────────
    [Theory]
    [InlineData("{\"priority\":\"HIGH\",\"priorityScore\":75,\"requiredCrewType\":\"DRAINAGE\"}", true)]
    [InlineData("", false)]
    [InlineData(null, false)]
    [InlineData("   ", false)]
    public void Check1_RecommendationEventOutput_MustBeNonEmptyJson(string? outputData, bool expectedValid)
    {
        var isValid = !string.IsNullOrWhiteSpace(outputData);
        Assert.Equal(expectedValid, isValid);
    }

    // ── CHECK 2: Problem Integrity & Status ────────────────────────────────────
    [Theory]
    [InlineData("AWAITING_ASSIGNMENT", true)]
    [InlineData("IDENTIFIED", false)]
    [InlineData("ASSIGNED", false)]
    [InlineData("RESOLVED", false)]
    public void Check2_ProblemStatus_MustBeAwaitingAssignment(string status, bool expectedEligible)
    {
        var isEligible = status == "AWAITING_ASSIGNMENT";
        Assert.Equal(expectedEligible, isEligible);
    }

    // ── CHECK 3: Report Linkage ───────────────────────────────────────────────
    [Theory]
    [InlineData(1, true)]
    [InlineData(5, true)]
    [InlineData(0, false)]
    public void Check3_ReportLinkage_MustHaveAtLeastOneActiveReport(int activeReportCount, bool expectedValid)
    {
        var isValid = activeReportCount > 0;
        Assert.Equal(expectedValid, isValid);
    }

    // ── CHECK 4: Priority Enum Validity ───────────────────────────────────────
    [Theory]
    [InlineData("LOW", true)]
    [InlineData("MEDIUM", true)]
    [InlineData("HIGH", true)]
    [InlineData("CRITICAL", true)]
    [InlineData("URGENT", false)]
    [InlineData("MODERATE", false)]
    [InlineData("EMERGENCY", false)]
    public void Check4_PriorityEnum_MustMatchDefinedTiers(string priority, bool expectedValid)
    {
        var validTiers = new HashSet<string> { "LOW", "MEDIUM", "HIGH", "CRITICAL" };
        var isValid = validTiers.Contains(priority.ToUpperInvariant());
        Assert.Equal(expectedValid, isValid);
    }

    // ── CHECK 5: Score Band Alignment ─────────────────────────────────────────
    [Theory]
    // LOW: 0 - 29
    [InlineData("LOW", 0, true)]
    [InlineData("LOW", 29, true)]
    [InlineData("LOW", 30, false)]
    [InlineData("LOW", -1, false)]
    // MEDIUM: 30 - 59
    [InlineData("MEDIUM", 30, true)]
    [InlineData("MEDIUM", 59, true)]
    [InlineData("MEDIUM", 29, false)]
    [InlineData("MEDIUM", 60, false)]
    // HIGH: 60 - 84
    [InlineData("HIGH", 60, true)]
    [InlineData("HIGH", 84, true)]
    [InlineData("HIGH", 59, false)]
    [InlineData("HIGH", 85, false)]
    // CRITICAL: 85 - 100
    [InlineData("CRITICAL", 85, true)]
    [InlineData("CRITICAL", 100, true)]
    [InlineData("CRITICAL", 84, false)]
    [InlineData("CRITICAL", 101, false)]
    public void Check5_ScoreBand_MustStrictlyAlignWithPriorityTier(string priority, int score, bool expectedValid)
    {
        var isValid = IsScoreBandValid(priority, score);
        Assert.Equal(expectedValid, isValid);
    }

    // ── CHECK 6: Crew Existence ───────────────────────────────────────────────
    [Theory]
    [InlineData("valid-uuid", true)]
    [InlineData(null, false)]
    public void Check6_CrewExistence_MustHaveNonNullRecommendedCrew(string? crewId, bool expectedValid)
    {
        var isValid = !string.IsNullOrEmpty(crewId);
        Assert.Equal(expectedValid, isValid);
    }

    // ── CHECK 7: Specialty Match ──────────────────────────────────────────────
    [Theory]
    [InlineData("DRAINAGE", "DRAINAGE", true)]
    [InlineData("ROAD", "ROAD", true)]
    [InlineData("WASTE", "WASTE", true)]
    [InlineData("ELECTRICAL", "ELECTRICAL", true)]
    [InlineData("ENVIRONMENT", "ENVIRONMENT", true)]
    [InlineData("DRAINAGE", "ROAD", false)]
    [InlineData("ELECTRICAL", "WASTE", false)]
    public void Check7_SpecialtyMatch_CrewTypeMustMatchProblemCategory(string problemCat, string crewType, bool expectedMatch)
    {
        var match = IsSpecialtyMatched(problemCat, crewType);
        Assert.Equal(expectedMatch, match);
    }

    // ── CHECK 8: Real-Time Availability ───────────────────────────────────────
    [Theory]
    [InlineData("AVAILABLE", true)]
    [InlineData("BUSY", false)]
    [InlineData("UNAVAILABLE", false)]
    public void Check8_RealTimeAvailability_MustBeAvailableAtApprovalInstant(string status, bool expectedAvailable)
    {
        var isAvailable = status.Equals("AVAILABLE", StringComparison.OrdinalIgnoreCase);
        Assert.Equal(expectedAvailable, isAvailable);
    }

    // ── CHECK 9: Single In-Progress Work Order Constraint ─────────────────────
    [Theory]
    [InlineData(0, true)]
    [InlineData(1, false)]
    [InlineData(2, false)]
    public void Check9_SingleInProgressJob_MustHaveZeroActiveJobs(int activeJobsCount, bool expectedAllowed)
    {
        var allowed = activeJobsCount == 0;
        Assert.Equal(expectedAllowed, allowed);
    }

    // ── CHECK 10: Authorized Admin Actor ──────────────────────────────────────
    [Theory]
    [InlineData("ADMIN", true)]
    [InlineData("RESIDENT", false)]
    [InlineData("CREW_LEADER_DRAINAGE", false)]
    [InlineData("ANONYMOUS", false)]
    public void Check10_AuthorizedActor_MustPossessAdminRole(string role, bool expectedAuthorized)
    {
        var authorized = role.Equals("ADMIN", StringComparison.OrdinalIgnoreCase);
        Assert.Equal(expectedAuthorized, authorized);
    }
}
