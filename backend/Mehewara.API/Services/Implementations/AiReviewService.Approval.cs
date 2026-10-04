using System.Text.Json;
using System.Text.Json.Nodes;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class AiReviewService
{
    // Only the supported editable fields count as a human override. Whitespace,
    // UUID formatting and serialization changes cannot grant the AI-review exemption.
    internal static bool HasMeaningfulEdit(JsonObject before, JsonObject after)
    {
        foreach (var field in new[] { "priority", "requiredCrewType" })
            if (Text(before[field]).Trim().ToUpperInvariant() != Text(after[field]).Trim().ToUpperInvariant()) return true;
        if (Id(before["recommendedCrewId"]) != Id(after["recommendedCrewId"])) return true;
        var sameScore = before["priorityScore"] is JsonValue beforeScore && beforeScore.TryGetValue<double>(out var oldScore) &&
            after["priorityScore"] is JsonValue afterScore && afterScore.TryGetValue<double>(out var newScore) && oldScore == newScore;
        if (!sameScore && !JsonNode.DeepEquals(before["priorityScore"], after["priorityScore"])) return true;
        if (Text(before["recommendationReason"]).Trim() != Text(after["recommendationReason"]).Trim()) return true;
        var beforeReasons = (before["priorityReasons"] as JsonArray ?? new()).Select(n => Text(n).Trim());
        var afterReasons = (after["priorityReasons"] as JsonArray ?? new()).Select(n => Text(n).Trim());
        return !beforeReasons.SequenceEqual(afterReasons);
    }

    public async Task<RecommendationReviewMetadata?> GetHumanOverrideAsync(WorkflowEvent ev)
    {
        var metadata = ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData);
        if (metadata?.Origin != ReviewOrigins.HumanOverride || metadata.Revision != ev.Revision ||
            ev.Revision <= 1 || ev.OriginalOutputData == null) return null;
        var audits = await db.ActivityHistories.AsNoTracking().Where(a => a.RecommendationId == ev.WorkflowEventId &&
            a.Action == "RECOMMENDATION_EDITED" && a.ActorUserId == metadata.EditedBy)
            .OrderByDescending(a => a.CreatedAt).ToListAsync();
        foreach (var audit in audits)
        {
            var beforeMetadata = ReviewMetadataJson.Read<RecommendationAuditMetadata>(audit.BeforeData);
            var afterMetadata = ReviewMetadataJson.Read<RecommendationAuditMetadata>(audit.AfterData);
            if (beforeMetadata?.Revision != ev.Revision - 1 || afterMetadata?.Revision != ev.Revision ||
                afterMetadata.Origin != ReviewOrigins.HumanOverride || string.IsNullOrWhiteSpace(audit.Note) ||
                !metadata.EditedAt.HasValue || (audit.CreatedAt - metadata.EditedAt.Value.UtcDateTime).Duration() >= TimeSpan.FromMilliseconds(1)) continue;
            try
            {
                var before = Obj(audit.BeforeData); var after = Obj(audit.AfterData);
                before.Remove(ReviewMetadataJson.Key); after.Remove(ReviewMetadataJson.Key);
                if (JsonNode.DeepEquals(after, Obj(ev.OutputData)) && HasMeaningfulEdit(before, after)) return metadata;
            }
            catch (JsonException) { /* malformed legacy audit cannot grant an exemption */ }
            catch (InvalidOperationException) { }
        }
        return null;
    }

    internal static bool ApprovalFieldsValid(JsonObject payload)
    {
        if (!Id(payload["problemId"]).HasValue || !Id(payload["recommendedCrewId"]).HasValue ||
            payload["priorityScore"] is not JsonValue scoreValue || !scoreValue.TryGetValue<int>(out var score)) return false;
        var validScore = Text(payload["priority"]) switch {
            "LOW" => score is >= 0 and <= 29, "MEDIUM" => score is >= 30 and <= 59,
            "HIGH" => score is >= 60 and <= 84, "CRITICAL" => score is >= 85 and <= 100, _ => false };
        if (!validScore || !new[] { "ROAD", "DRAINAGE", "WASTE", "ELECTRICAL", "ENVIRONMENT" }.Contains(Text(payload["requiredCrewType"])) ||
            payload["recommendationReason"] is not JsonValue reason || !reason.TryGetValue<string>(out var reasonText) || string.IsNullOrWhiteSpace(reasonText) ||
            payload["priorityReasons"] is not JsonArray { Count: > 0 } reasons ||
            reasons.Any(n => n is not JsonValue value || !value.TryGetValue<string>(out var text) || string.IsNullOrWhiteSpace(text))) return false;
        if (payload["estimatedDurationMinutes"] is JsonNode duration &&
            (duration is not JsonValue dv || !dv.TryGetValue<int>(out var durationMinutes) || durationMinutes is < 10 or > 2880)) return false;
        if (payload["distanceKm"] is JsonNode distance &&
            (distance is not JsonValue kv || !kv.TryGetValue<double>(out var km) || !double.IsFinite(km) || km < 0)) return false;
        if (payload["estimatedTravelMinutes"] is JsonNode travel &&
            (travel is not JsonValue tv || !tv.TryGetValue<int>(out var travelMinutes) || travelMinutes < 0)) return false;
        return payload["dispatchStrategy"] == null || new[] { "STANDARD_DISPATCH", "IMMEDIATE_QUICK_WIN",
            "URGENT_CRITICAL_PRIORITY", "CLUSTERED_EN_ROUTE" }.Contains(Text(payload["dispatchStrategy"]));
    }

    // A human edit does not change Agent 2 report references or authorize unrelated reports.
    public async Task<Guid[]?> GetApprovalReportIdsAsync(WorkflowEvent ev)
    {
        try
        {
            var saved = Obj(ev.WorkflowRun.InputData);
            if (saved["context"]?["complete"] is not JsonValue complete || !complete.TryGetValue<bool>(out var loaded) || !loaded) return null;
            var consolidation = await db.WorkflowEvents.AsNoTracking().Where(e => e.WorkflowRunId == ev.WorkflowRunId && e.Stage == "PROBLEM_CONSOLIDATION")
                .OrderByDescending(e => e.StartedAt).Select(e => e.OutputData).FirstOrDefaultAsync();
            var proposal = Obj(consolidation);
            if (Id(proposal["reportId"]) != ev.WorkflowRun.ReportId ||
                !(Text(proposal["decision"]) == "CREATE_NEW" && proposal["newProblem"] is JsonObject ||
                  Text(proposal["decision"]) == "LINK_EXISTING" && Id(proposal["problemId"]) == ev.WorkflowRun.ProblemId)) return null;
            var references = proposal["relatedReportIds"] as JsonArray;
            if (references == null || references.Count == 0) return null;
            var ids = references.Select(Id).ToArray();
            if (ids.Any(i => !i.HasValue || i == Guid.Empty)) return null;
            var result = ids.Select(i => i!.Value).ToArray();
            var authorized = (saved["context"]?["relatedReports"] as JsonArray ?? new()).Select(r => Id(r?["reportId"]))
                .Where(i => i.HasValue).Select(i => i!.Value).Append(ev.WorkflowRun.ReportId).ToHashSet();
            return result.Distinct().Count() == result.Length && result.Contains(ev.WorkflowRun.ReportId) && result.All(authorized.Contains)
                ? result : null;
        }
        catch (JsonException) { return null; }
        catch (InvalidOperationException) { return null; }
    }
}
