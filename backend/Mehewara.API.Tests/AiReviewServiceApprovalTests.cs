using System.Text.Json.Nodes;
using Mehewara.API.Services.Implementations;
using Xunit;

namespace Mehewara.API.Tests;

public class ApprovalFieldsValidTests
{
    private static JsonObject ValidPayload() => new()
    {
        ["problemId"] = Guid.NewGuid().ToString(),
        ["recommendedCrewId"] = Guid.NewGuid().ToString(),
        ["priority"] = "HIGH",
        ["priorityScore"] = 70,
        ["requiredCrewType"] = "ROAD",
        ["recommendationReason"] = "Road crew needed to repair the pothole urgently",
        ["priorityReasons"] = new JsonArray("Blocks traffic near a school entrance"),
        ["estimatedDurationMinutes"] = 90,
        ["distanceKm"] = 2.5,
        ["estimatedTravelMinutes"] = 15,
        ["dispatchStrategy"] = "STANDARD_DISPATCH",
    };

    [Fact]
    public void ValidPayload_PassesAllChecks()
    {
        Assert.True(AiReviewService.ApprovalFieldsValid(ValidPayload()));
    }

    [Fact]
    public void MissingProblemId_Fails()
    {
        var payload = ValidPayload();
        payload.Remove("problemId");
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void MissingRecommendedCrewId_Fails()
    {
        var payload = ValidPayload();
        payload.Remove("recommendedCrewId");
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Theory]
    [InlineData("LOW", 29, true)]
    [InlineData("LOW", 30, false)]
    [InlineData("MEDIUM", 30, true)]
    [InlineData("MEDIUM", 29, false)]
    [InlineData("HIGH", 84, true)]
    [InlineData("HIGH", 85, false)]
    [InlineData("CRITICAL", 85, true)]
    [InlineData("CRITICAL", 100, true)]
    [InlineData("CRITICAL", 101, false)]
    public void PriorityScoreMustMatchPolicyBand(string priority, int score, bool expected)
    {
        var payload = ValidPayload();
        payload["priority"] = priority;
        payload["priorityScore"] = score;
        Assert.Equal(expected, AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void UnknownPriority_Fails()
    {
        var payload = ValidPayload();
        payload["priority"] = "URGENT";
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Theory]
    [InlineData("ROAD", true)]
    [InlineData("DRAINAGE", true)]
    [InlineData("WASTE", true)]
    [InlineData("ELECTRICAL", true)]
    [InlineData("ENVIRONMENT", true)]
    [InlineData("PLUMBING", false)]
    public void RequiredCrewTypeMustBeASupportedSpecialty(string crewType, bool expected)
    {
        var payload = ValidPayload();
        payload["requiredCrewType"] = crewType;
        Assert.Equal(expected, AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void BlankRecommendationReason_Fails()
    {
        var payload = ValidPayload();
        payload["recommendationReason"] = "   ";
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void EmptyPriorityReasons_Fails()
    {
        var payload = ValidPayload();
        payload["priorityReasons"] = new JsonArray();
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void PriorityReasonsWithABlankEntry_Fails()
    {
        var payload = ValidPayload();
        payload["priorityReasons"] = new JsonArray("Valid reason", "   ");
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Theory]
    [InlineData(9)]
    [InlineData(2881)]
    public void EstimatedDurationOutsideBounds_Fails(int minutes)
    {
        var payload = ValidPayload();
        payload["estimatedDurationMinutes"] = minutes;
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void NegativeDistance_Fails()
    {
        var payload = ValidPayload();
        payload["distanceKm"] = -1.0;
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void NegativeEstimatedTravelMinutes_Fails()
    {
        var payload = ValidPayload();
        payload["estimatedTravelMinutes"] = -5;
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void MissingDispatchStrategy_IsAllowed()
    {
        var payload = ValidPayload();
        payload.Remove("dispatchStrategy");
        Assert.True(AiReviewService.ApprovalFieldsValid(payload));
    }

    [Fact]
    public void UnknownDispatchStrategy_Fails()
    {
        var payload = ValidPayload();
        payload["dispatchStrategy"] = "SOMEDAY_MAYBE";
        Assert.False(AiReviewService.ApprovalFieldsValid(payload));
    }
}

public class HasMeaningfulEditTests
{
    private static JsonObject BasePayload() => new()
    {
        ["priority"] = "HIGH",
        ["requiredCrewType"] = "ROAD",
        ["recommendedCrewId"] = "11111111-1111-1111-1111-111111111111",
        ["priorityScore"] = 70,
        ["recommendationReason"] = "Road crew needed urgently",
        ["priorityReasons"] = new JsonArray("Blocks traffic"),
    };

    [Fact]
    public void IdenticalPayloads_AreNotAMeaningfulEdit()
    {
        Assert.False(AiReviewService.HasMeaningfulEdit(BasePayload(), BasePayload()));
    }

    [Fact]
    public void CaseAndWhitespaceOnlyDifferences_AreNotMeaningful()
    {
        var after = BasePayload();
        after["priority"] = "  high  ";
        after["requiredCrewType"] = "road";
        after["recommendationReason"] = "  Road crew needed urgently  ";
        Assert.False(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void ChangingPriority_IsMeaningful()
    {
        var after = BasePayload();
        after["priority"] = "CRITICAL";
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void ChangingRequiredCrewType_IsMeaningful()
    {
        var after = BasePayload();
        after["requiredCrewType"] = "DRAINAGE";
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void ChangingRecommendedCrewId_IsMeaningful()
    {
        var after = BasePayload();
        after["recommendedCrewId"] = "22222222-2222-2222-2222-222222222222";
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void ChangingPriorityScore_IsMeaningful()
    {
        var after = BasePayload();
        after["priorityScore"] = 71;
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void SameScoreAsIntOrDouble_IsNotMeaningful()
    {
        var before = BasePayload();
        before["priorityScore"] = 70;
        var after = BasePayload();
        after["priorityScore"] = 70.0;
        Assert.False(AiReviewService.HasMeaningfulEdit(before, after));
    }

    [Fact]
    public void ChangingRecommendationReasonText_IsMeaningful()
    {
        var after = BasePayload();
        after["recommendationReason"] = "A completely different justification";
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }

    [Fact]
    public void ReorderingOrChangingPriorityReasons_IsMeaningful()
    {
        var after = BasePayload();
        after["priorityReasons"] = new JsonArray("Blocks traffic", "Near a school");
        Assert.True(AiReviewService.HasMeaningfulEdit(BasePayload(), after));
    }
}
