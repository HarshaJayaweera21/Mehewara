using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Mehewara.API.Data;
using Mehewara.API.DTOs.Dispatch;
using Mehewara.API.Exceptions;
using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Services.Implementations;

public partial class AiReviewService(AppDbContext db, IHttpClientFactory clients, IConfiguration config)
{
    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    internal static JsonObject Obj(string? value) => string.IsNullOrWhiteSpace(value) ? new() : JsonNode.Parse(value)!.AsObject();
    internal static string Text(JsonNode? n) => n?.ToString() ?? "";
    internal static Guid? Id(JsonNode? n) => Guid.TryParse(Text(n), out var id) ? id : null;
    internal static JsonNode Node(object value) => JsonSerializer.SerializeToNode(value, Json)!;
    internal static string Hash(JsonNode node) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(node.ToJsonString(Json))));

    public async Task<WorkflowEvent> LockRecommendationAsync(Guid id, int? revision = null)
    {
        // Every mutation locks workflow -> recommendation -> Problem -> crew in that order.
        var runId = await db.WorkflowEvents.Where(e => e.WorkflowEventId == id && e.Stage == "PRIORITIZATION")
            .Select(e => (Guid?)e.WorkflowRunId).FirstOrDefaultAsync()
            ?? throw new NotFoundException("Recommendation not found.", "RECOMMENDATION_NOT_FOUND");
        var run = await db.WorkflowRuns.FromSqlInterpolated($"SELECT * FROM workflow_runs WHERE workflow_run_id = {runId} FOR UPDATE").SingleAsync();
        var ev = await db.WorkflowEvents.FromSqlInterpolated($"SELECT * FROM workflow_events WHERE workflow_event_id = {id} FOR UPDATE").SingleAsync();
        ev.WorkflowRun = run;
        if (run.CurrentRecommendationId != id || (revision.HasValue && ev.Revision != revision))
            throw new ConflictException("Recommendation has changed or is superseded. Refresh it.", "STALE_RECOMMENDATION");
        if (await db.ApprovalHistories.AnyAsync(a => a.RecommendationId == id && (a.Decision == "APPROVED" || a.Decision == "REJECTED")))
            throw new ConflictException("Recommendation has already been reviewed.", "ALREADY_REVIEWED");
        if (await db.AiReviewJobs.AnyAsync(j => j.WorkflowRunId == runId && (j.Status == "QUEUED" || j.Status == "RUNNING")))
            throw new ConflictException("AI review is running. Wait for its result.", "REVIEW_RUNNING");
        return ev;
    }

    public async Task<JsonObject> GetEvidenceAsync(ValidationContextRequest request)
    {
        var run = await db.WorkflowRuns.AsNoTracking().SingleOrDefaultAsync(r => r.WorkflowRunId == request.WorkflowId)
            ?? throw new NotFoundException("Workflow not found.", "WORKFLOW_NOT_FOUND");
        string? input = run.InputData;
        if (request.JobId.HasValue)
        {
            var job = await db.AiReviewJobs.AsNoTracking().SingleOrDefaultAsync(j => j.Id == request.JobId && j.WorkflowRunId == request.WorkflowId)
                ?? throw new BadRequestException("Review context is not authorized.");
            if (job.Status != "RUNNING" || job.LeaseUntil == null || job.LeaseUntil <= DateTime.UtcNow)
                throw new BadRequestException("Review job has no active evidence lease.");
            input = job.InputData;
        }
        if (input == null) throw new BadRequestException("Saved input evidence is unavailable. Start validation from the coordinator screen.");
        var snapshot = Obj(input);
        var context = snapshot["context"]?.AsObject() ?? new();
        if (context["complete"]?.GetValue<bool>() != true) throw new BadRequestException("Context completeness is missing or loading failed; rebuild context before validation.");
        HashSet<Guid> Allowed(string field, string key) => (context[field]?.AsArray() ?? new())
            .Select(n => Id(n?[key])).Where(i => i.HasValue).Select(i => i!.Value).ToHashSet();
        var reports = Allowed("relatedReports", "reportId");
        reports.Add(run.ReportId);
        if (request.ReportIds.Count > 100 || request.ReportIds.Any(id => !reports.Contains(id)) ||
            (request.ProblemId.HasValue && !Allowed("candidateProblems", "problemId").Contains(request.ProblemId.Value)) ||
            (request.CrewId.HasValue && !Allowed("availableCrews", "crewId").Contains(request.CrewId.Value)))
            throw new BadRequestException("Evidence references are outside the authorized workflow context.");
        return await LoadEvidenceAsync(request, run.ReportId);
    }

    private async Task<JsonObject> LoadEvidenceAsync(ValidationContextRequest request, Guid sourceReportId)
    {
        var ids = request.ReportIds.Append(sourceReportId).Distinct().OrderBy(id => id).ToList();
        var reports = await db.Reports.AsNoTracking().Where(r => ids.Contains(r.ReportId)).OrderBy(r => r.ReportId)
            .Select(r => new { id = r.ReportId, r.Description, r.Category, r.Latitude, r.Longitude, r.Address,
                r.ProblemId, r.Status }).ToListAsync();
        var problem = await db.Problems.AsNoTracking().Where(p => p.ProblemId == request.ProblemId)
            .Select(p => new { problemId = p.ProblemId, p.Title, p.Description, p.Category, p.Latitude, p.Longitude, p.Address, p.Status }).FirstOrDefaultAsync();
        var crew = await db.Crews.AsNoTracking().Where(c => c.CrewId == request.CrewId)
            .Select(c => new { crewId = c.CrewId, name = c.CrewName, c.CrewType, c.Status }).FirstOrDefaultAsync();
        var active = await db.WorkOrders.AsNoTracking().Where(w => (w.ProblemId == request.ProblemId || w.CrewId == request.CrewId)
            && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))
            .OrderBy(w => w.WorkOrderId)
            .Select(w => new { w.WorkOrderId, w.ProblemId, w.CrewId, w.Status }).ToListAsync();
        // Hash semantic evidence only. Availability and lifecycle are rechecked live at approval.
        var semantic = Node(new {
            reports = reports.Select(r => new { r.id, r.Description, r.Category, r.Latitude, r.Longitude, r.Address, r.ProblemId }),
            problem = problem == null ? null : new { problem.problemId, problem.Title, problem.Description, problem.Category, problem.Latitude, problem.Longitude, problem.Address },
            crew = crew == null ? null : new { crew.crewId, crew.CrewType }
        });
        // Full review fingerprint includes lifecycle and active work. Exclude only the
        // retrieval timestamp so an unchanged fresh read can match the reviewed snapshot.
        var snapshot = Node(new { reports, problem, crew, activeWorkOrders = active });
        return Node(new { reports, problem, crew, activeWorkOrders = active, snapshotAt = DateTime.UtcNow,
            complete = reports.Count == ids.Count && (!request.ProblemId.HasValue || problem != null) && (!request.CrewId.HasValue || crew != null),
            loading = new { reports = reports.Count == ids.Count ? "LOADED" : "MISSING",
                problem = !request.ProblemId.HasValue ? "NOT_REQUESTED" : problem == null ? "MISSING" : "LOADED",
                crew = !request.CrewId.HasValue ? "NOT_REQUESTED" : crew == null ? "MISSING" : "LOADED",
                activeWorkOrders = "LOADED" },
            evidenceHash = Hash(semantic), snapshotHash = Hash(snapshot) }).AsObject();
    }

    public async Task<bool> EvidenceMatchesAsync(WorkflowEvent ev)
    {
        if (ev.EvidenceRequest == null || ev.EvidenceHash == null) return false;
        var request = JsonSerializer.Deserialize<ValidationContextRequest>(ev.EvidenceRequest, Json)!;
        var source = await db.WorkflowRuns.Where(r => r.WorkflowRunId == ev.WorkflowRunId).Select(r => r.ReportId).SingleAsync();
        var evidence = await LoadEvidenceAsync(request, source);
        return evidence["complete"]?.GetValue<bool>() == true && Text(evidence["evidenceHash"]) == ev.EvidenceHash;
    }

    public async Task<bool> CanApproveAsync(WorkflowEvent ev)
    {
        if (ev.WorkflowRun.CurrentRecommendationId != ev.WorkflowEventId ||
            await db.AiReviewJobs.AnyAsync(j => j.WorkflowRunId == ev.WorkflowRunId && (j.Status == "QUEUED" || j.Status == "RUNNING"))) return false;
        if (await db.ApprovalHistories.AnyAsync(a => a.RecommendationId == ev.WorkflowEventId && (a.Decision == "APPROVED" || a.Decision == "REJECTED"))) return false;
        var humanOverride = await GetHumanOverrideAsync(ev);
        if (ReviewMetadataJson.Read<RecommendationReviewMetadata>(ev.InputData)?.Origin == ReviewOrigins.HumanOverride && humanOverride == null) return false;
        if (humanOverride == null && (ev.ValidatedRevision != ev.Revision || Text(Obj(ev.ValidationResult)["status"]) != "VALID")) return false;
        var payload = Obj(ev.OutputData); var pid = Id(payload["problemId"]); var cid = Id(payload["recommendedCrewId"]);
        if (!ApprovalFieldsValid(payload) || !pid.HasValue || !cid.HasValue || pid != ev.WorkflowRun.ProblemId) return false;
        var problem = await db.Problems.AsNoTracking().SingleOrDefaultAsync(p => p.ProblemId == pid);
        var crew = await db.Crews.AsNoTracking().SingleOrDefaultAsync(c => c.CrewId == cid);
        if (problem == null || problem.Status is "ASSIGNED" or "IN_PROGRESS" or "RESOLVED" or "CLOSED" or "CANCELLED" ||
            crew == null || crew.Status != "AVAILABLE" || crew.CrewType != Text(payload["requiredCrewType"]) ||
            crew.CrewType != problem.Category) return false;
        if (await db.WorkOrders.AnyAsync(w => (w.ProblemId == pid || w.CrewId == cid) && (w.Status == "ASSIGNED" || w.Status == "IN_PROGRESS"))) return false;
        var reportIds = await GetApprovalReportIdsAsync(ev);
        if (reportIds == null || await db.Reports.CountAsync(r => reportIds.Contains(r.ReportId) && r.ProblemId == pid && r.Status != "CANCELLED") != reportIds.Length) return false;
        return humanOverride != null || await EvidenceMatchesAsync(ev);
    }
}
