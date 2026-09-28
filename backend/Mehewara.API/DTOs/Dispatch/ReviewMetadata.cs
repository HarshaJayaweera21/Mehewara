using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Mehewara.API.DTOs.Dispatch;

// JSON contracts only: these types are not EF entities and require no migration.
public abstract record ReviewMetadata
{
    public required int SchemaVersion { get; init; }
    [JsonExtensionData] public Dictionary<string, JsonElement>? AdditionalFields { get; init; }
}

public static class ReviewOrigins
{
    public const string System = "SYSTEM";
    public const string Coordinator = "COORDINATOR";
    public const string AiGenerated = "AI_GENERATED";
    public const string HumanOverride = "HUMAN_OVERRIDE";
}

public sealed record ReviewFeedbackMetadata
{
    public required string Status { get; init; }
    public List<string> Issues { get; init; } = new();
    public List<Guid> RejectedCrewIds { get; init; } = new();
    public string? SuggestedAction { get; init; }
    public string? CoordinatorReason { get; init; }
}

public sealed record ReviewJobMetadata : ReviewMetadata
{
    public required Guid ChainId { get; init; }
    public Guid? ParentJobId { get; init; }
    public required string Origin { get; init; }
    // Domain corrections are distinct from AiReviewJob.Attempts (worker claims).
    public required int CorrectionCount { get; init; }
    public int EvidenceRetryCount { get; init; }
    public DateTimeOffset? NextAttemptAt { get; init; }
    // Numeric selector avoids timestamp casts on legacy/malformed JSON in PostgreSQL.
    public long? NextAttemptUnixSeconds { get; init; }
    public ReviewFeedbackMetadata? Feedback { get; init; }
}

public sealed record RecommendationReviewMetadata : ReviewMetadata
{
    public required string Origin { get; init; }
    public required int Revision { get; init; }
    public Guid? JobId { get; init; }
    public Guid? ChainId { get; init; }
    public Guid? EditedBy { get; init; }
    public DateTimeOffset? EditedAt { get; init; }
}

public sealed record ValidationReviewMetadata : ReviewMetadata
{
    public Guid? RecommendationId { get; init; }
    public int? Revision { get; init; }
    public Guid? JobId { get; init; }
    public Guid? ChainId { get; init; }
    public int? WorkerAttempt { get; init; }
}

public sealed record WorkflowReviewMetadata : ReviewMetadata
{
    public Guid? RecommendationId { get; init; }
    public int? Revision { get; init; }
    public Guid? JobId { get; init; }
    public Guid? ChainId { get; init; }
    // Tracking only, never an approval decision or a database status enum.
    public required string Progress { get; init; }
    public string? AttentionReason { get; init; }
    public required DateTimeOffset UpdatedAt { get; init; }
}

public sealed record RecommendationAuditMetadata : ReviewMetadata
{
    public required int Revision { get; init; }
    // Null means legacy/unknown provenance, not AI validation or human approval.
    public string? Origin { get; init; }
}

public static class ReviewMetadataJson
{
    public const int CurrentVersion = 1;
    public const string Key = "reviewMetadata";
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    // Missing, unsupported or malformed metadata stays unknown; never synthesize VALID
    // or infer HUMAN_OVERRIDE for legacy records. Callers decide whether to block/retry.
    public static T? Read<T>(string? json) where T : ReviewMetadata
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            var root = JsonNode.Parse(json) as JsonObject;
            var metadata = root?[Key]?.Deserialize<T>(Options);
            return metadata != null && IsSupported(metadata) ? metadata : null;
        }
        catch (JsonException) { return null; }
        catch (InvalidOperationException) { return null; }
    }

    // Preserve the payload and unknown sibling fields. Never replace evidence/context
    // with metadata or accept metadata returned by the model as authoritative.
    public static string Write<T>(string? json, T metadata) where T : ReviewMetadata
    {
        if (!IsSupported(metadata)) throw new ArgumentException("Invalid review metadata.", nameof(metadata));
        var root = string.IsNullOrWhiteSpace(json) ? new JsonObject() :
            JsonNode.Parse(json) as JsonObject ?? throw new JsonException("Review data must be a JSON object.");
        root[Key] = JsonSerializer.SerializeToNode(metadata, Options);
        return root.ToJsonString(Options);
    }

    // Refresh execution fields while retaining chain, feedback, scheduling and any
    // other saved fields. Fresh backend evidence replaces the old context as a unit.
    public static JsonObject MergeExecutionContext(string? savedJson, JsonObject freshContext)
    {
        var saved = string.IsNullOrWhiteSpace(savedJson) ? new JsonObject() :
            JsonNode.Parse(savedJson) as JsonObject ?? throw new JsonException("Review data must be a JSON object.");
        foreach (var entry in freshContext)
        {
            if (entry.Key == Key) throw new ArgumentException("Execution context cannot replace review metadata.");
            saved[entry.Key] = entry.Value?.DeepClone();
        }
        return saved;
    }

    private static bool IsSupported(ReviewMetadata metadata) => metadata.SchemaVersion == CurrentVersion && (metadata switch
    {
        ReviewJobMetadata job => job.ChainId != Guid.Empty && job.CorrectionCount >= 0 && job.EvidenceRetryCount >= 0 &&
            (job.NextAttemptUnixSeconds == null || job.NextAttemptUnixSeconds >= 0) &&
            job.ParentJobId != Guid.Empty && job.Origin is ReviewOrigins.System or ReviewOrigins.Coordinator,
        RecommendationReviewMetadata rec => rec.Revision > 0 &&
            (rec.Origin == ReviewOrigins.AiGenerated || (rec.Origin == ReviewOrigins.HumanOverride &&
                rec.EditedBy.HasValue && rec.EditedBy != Guid.Empty && rec.EditedAt.HasValue)),
        ValidationReviewMetadata validation => (validation.RecommendationId == null && validation.Revision == null) ||
            (validation.RecommendationId.HasValue && validation.RecommendationId != Guid.Empty && validation.Revision > 0),
        WorkflowReviewMetadata workflow => workflow.UpdatedAt != default &&
            workflow.Progress is "QUEUED" or "RUNNING" or "VALIDATED" or "NEEDS_ATTENTION",
        RecommendationAuditMetadata audit => audit.Revision > 0 &&
            audit.Origin is null or ReviewOrigins.AiGenerated or ReviewOrigins.HumanOverride,
        _ => false
    });
}
