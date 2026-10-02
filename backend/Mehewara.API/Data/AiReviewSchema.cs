using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Data;

// Kept separate so the runtime model and manually maintained migration snapshot agree.
public static class AiReviewSchema
{
    public static void Configure(ModelBuilder builder)
    {
        var run = builder.Entity<WorkflowRun>();
        run.Property(x => x.InputData).HasColumnName("input_data").HasColumnType("jsonb");
        run.Property(x => x.CurrentRecommendationId).HasColumnName("current_recommendation_id");
        var ev = builder.Entity<WorkflowEvent>();
        ev.Property(x => x.Revision).HasColumnName("revision").HasDefaultValue(1);
        ev.Property(x => x.PreviousRecommendationId).HasColumnName("previous_recommendation_id");
        ev.Property(x => x.OriginalOutputData).HasColumnName("original_output_data").HasColumnType("jsonb");
        ev.Property(x => x.ValidatedRevision).HasColumnName("validated_revision");
        ev.Property(x => x.EvidenceHash).HasColumnName("evidence_hash");
        ev.Property(x => x.EvidenceRequest).HasColumnName("evidence_request").HasColumnType("jsonb");
        var job = builder.Entity<AiReviewJob>();
        job.ToTable("ai_review_jobs", t => {
            t.HasCheckConstraint("ck_ai_review_job_status", "status IN ('QUEUED','RUNNING','COMPLETED','FAILED')");
            t.HasCheckConstraint("ck_ai_review_job_kind", "kind IN ('REGENERATE','VALIDATE')");
        });
        job.HasKey(x => x.Id);
        foreach (var property in typeof(AiReviewJob).GetProperties())
        {
            var column = System.Text.RegularExpressions.Regex.Replace(property.Name, "(?<!^)([A-Z])", "_$1").ToLowerInvariant();
            job.Property(property.Name).HasColumnName(column);
        }
        job.Property(x => x.InputData).HasColumnType("jsonb");
        job.HasIndex(x => x.RequestId).IsUnique();
        job.HasIndex(x => x.WorkflowRunId).IsUnique().HasFilter("status IN ('QUEUED','RUNNING')")
            .HasDatabaseName("ux_ai_review_jobs_active_workflow");
        job.HasOne<WorkflowRun>().WithMany().HasForeignKey(x => x.WorkflowRunId).OnDelete(DeleteBehavior.Restrict);
        job.HasOne<WorkflowEvent>().WithMany().HasForeignKey(x => x.RecommendationId).OnDelete(DeleteBehavior.Restrict);
        job.HasOne<User>().WithMany().HasForeignKey(x => x.RequestedBy).OnDelete(DeleteBehavior.Restrict);
    }
}
