using Mehewara.API.Models;
using Microsoft.EntityFrameworkCore;

namespace Mehewara.API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    // Database tables
    public DbSet<Role> Roles { get; set; }
    public DbSet<User> Users { get; set; }
    public DbSet<Report> Reports { get; set; }
    public DbSet<ReportPhoto> ReportPhotos { get; set; }
    public DbSet<Problem> Problems { get; set; }
    public DbSet<ReportProblem> ReportProblems { get; set; }
    public DbSet<Crew> Crews { get; set; }
    public DbSet<WorkOrder> WorkOrders { get; set; }
    public DbSet<ApprovalHistory> ApprovalHistories { get; set; }
    public DbSet<WorkflowRun> WorkflowRuns { get; set; }
    public DbSet<WorkflowEvent> WorkflowEvents { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        
        // 1. ROLES

        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable("roles");

            entity.HasKey(r => r.RoleId);

            entity.Property(r => r.RoleId)
                .HasColumnName("role_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(r => r.RoleName)
                .HasColumnName("role_name")
                .HasMaxLength(50)
                .IsRequired();

            entity.HasIndex(r => r.RoleName)
                .IsUnique();

            entity.Property(r => r.RoleCode)
                .HasColumnName("role_code")
                .HasMaxLength(50)
                .IsRequired();

            entity.HasIndex(r => r.RoleCode)
                .IsUnique();

            entity.Property(r => r.Description)
                .HasColumnName("description")
                .HasMaxLength(255);

            entity.Property(r => r.IsActive)
                .HasColumnName("is_active")
                .HasDefaultValue(true)
                .IsRequired();
        });

        
        // 2. USERS

        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("users");

            entity.HasKey(u => u.UserId);

            entity.Property(u => u.UserId)
                .HasColumnName("user_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(u => u.RoleId)
                .HasColumnName("role_id")
                .IsRequired();

            entity.Property(u => u.FirstName)
                .HasColumnName("first_name")
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(u => u.LastName)
                .HasColumnName("last_name")
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(u => u.Email)
                .HasColumnName("email")
                .HasMaxLength(255)
                .IsRequired();

            entity.HasIndex(u => u.Email)
                .IsUnique();

            entity.Property(u => u.PasswordHash)
                .HasColumnName("password_hash")
                .HasMaxLength(255)
                .IsRequired();

            entity.Property(u => u.PhoneNumber)
                .HasColumnName("phone_number")
                .HasMaxLength(20);

            entity.Property(u => u.ProfileImageUrl)
                .HasColumnName("profile_image_url")
                .HasMaxLength(500);

            entity.Property(u => u.IsActive)
                .HasColumnName("is_active")
                .HasDefaultValue(true)
                .IsRequired();

            entity.Property(u => u.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(u => u.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // Role → Users
            entity.HasOne(u => u.Role)
                .WithMany(r => r.Users)
                .HasForeignKey(u => u.RoleId)
                .OnDelete(DeleteBehavior.Restrict);

            // Indexes
            entity.HasIndex(u => u.RoleId)
                .HasDatabaseName("idx_users_role_id");

            entity.HasIndex(u => u.IsActive)
                .HasDatabaseName("idx_users_active");
        });

        
        // 3. CREWS

        modelBuilder.Entity<Crew>(entity =>
        {
            entity.ToTable("crews");

            entity.HasKey(c => c.CrewId);

            entity.Property(c => c.CrewId)
                .HasColumnName("crew_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(c => c.CrewName)
                .HasColumnName("crew_name")
                .HasMaxLength(100)
                .IsRequired();

            entity.HasIndex(c => c.CrewName)
                .IsUnique();

            entity.Property(c => c.CrewType)
                .HasColumnName("crew_type")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(c => c.CrewLeaderUserId)
                .HasColumnName("crew_leader_user_id");

            // One user can lead at most one crew.
            entity.HasIndex(c => c.CrewLeaderUserId)
                .IsUnique();

            entity.Property(c => c.Description)
                .HasColumnName("description");

            entity.Property(c => c.ContactNumber)
                .HasColumnName("contact_number")
                .HasMaxLength(20);

            entity.Property(c => c.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .HasDefaultValue("AVAILABLE")
                .IsRequired();

            entity.Property(c => c.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(c => c.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // User → Crew leader
            entity.HasOne(c => c.CrewLeaderUser)
                .WithMany()
                .HasForeignKey(c => c.CrewLeaderUserId)
                .OnDelete(DeleteBehavior.SetNull);

            // CHECK constraints
            entity.ToTable("crews", table =>
            {
                table.HasCheckConstraint(
                    "chk_crews_status",
                    "\"status\" IN ('AVAILABLE', 'BUSY', 'UNAVAILABLE')");

                table.HasCheckConstraint(
                    "chk_crews_type",
                    "\"crew_type\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");
            });

            // Indexes
            entity.HasIndex(c => c.CrewType)
                .HasDatabaseName("idx_crews_type");

            entity.HasIndex(c => c.Status)
                .HasDatabaseName("idx_crews_status");

            // SQL schema also defines a separate leader index.
            entity.HasIndex(c => c.CrewLeaderUserId)
                .HasDatabaseName("idx_crews_leader");
        });

    
        // 4. REPORTS

        modelBuilder.Entity<Report>(entity =>
        {
            entity.ToTable("reports");

            entity.HasKey(r => r.ReportId);

            entity.Property(r => r.ReportId)
                .HasColumnName("report_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(r => r.ResidentId)
                .HasColumnName("resident_id")
                .IsRequired();

            entity.Property(r => r.Description)
                .HasColumnName("description")
                .IsRequired();

            entity.Property(r => r.Category)
                .HasColumnName("category")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(r => r.Latitude)
                .HasColumnName("latitude")
                .HasPrecision(9, 6)
                .IsRequired();

            entity.Property(r => r.Longitude)
                .HasColumnName("longitude")
                .HasPrecision(9, 6)
                .IsRequired();

            entity.Property(r => r.Address)
                .HasColumnName("address");

            entity.Property(r => r.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .HasDefaultValue("PENDING")
                .IsRequired();

            entity.Property(r => r.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(r => r.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // User → Reports
            entity.HasOne(r => r.Resident)
                .WithMany()
                .HasForeignKey(r => r.ResidentId)
                .OnDelete(DeleteBehavior.Restrict);

            // CHECK constraints
            entity.ToTable("reports", table =>
            {
                table.HasCheckConstraint(
                    "chk_reports_status",
                    "\"status\" IN ('PENDING', 'PROCESSING', 'ASSIGNED', 'RESOLVED', 'CANCELLED')");

                table.HasCheckConstraint(
                    "chk_reports_category",
                    "\"category\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");

                table.HasCheckConstraint(
                    "chk_reports_latitude",
                    "\"latitude\" >= -90 AND \"latitude\" <= 90");

                table.HasCheckConstraint(
                    "chk_reports_longitude",
                    "\"longitude\" >= -180 AND \"longitude\" <= 180");
            });

            // Indexes
            entity.HasIndex(r => r.ResidentId)
                .HasDatabaseName("idx_reports_resident_id");

            entity.HasIndex(r => r.Status)
                .HasDatabaseName("idx_reports_status");

            entity.HasIndex(r => r.Category)
                .HasDatabaseName("idx_reports_category");

            entity.HasIndex(r => r.CreatedAt)
                .HasDatabaseName("idx_reports_created_at");

            entity.HasIndex(r => new { r.Latitude, r.Longitude })
                .HasDatabaseName("idx_reports_location");
        });

     
        // 5. REPORT PHOTOS

        modelBuilder.Entity<ReportPhoto>(entity =>
        {
            entity.ToTable("report_photos");

            entity.HasKey(p => p.PhotoId);

            entity.Property(p => p.PhotoId)
                .HasColumnName("photo_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(p => p.ReportId)
                .HasColumnName("report_id")
                .IsRequired();

            entity.Property(p => p.PhotoUrl)
                .HasColumnName("photo_url")
                .IsRequired();

            entity.Property(p => p.FileName)
                .HasColumnName("file_name")
                .HasMaxLength(255);

            entity.Property(p => p.MimeType)
                .HasColumnName("mime_type")
                .HasMaxLength(100);

            entity.Property(p => p.UploadedAt)
                .HasColumnName("uploaded_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // Report → Photos
            entity.HasOne(p => p.Report)
                .WithMany(r => r.Photos)
                .HasForeignKey(p => p.ReportId)
                .OnDelete(DeleteBehavior.Cascade);

            // Index
            entity.HasIndex(p => p.ReportId)
                .HasDatabaseName("idx_report_photos_report_id");
        });


        // 6. PROBLEMS

        modelBuilder.Entity<Problem>(entity =>
        {
            entity.ToTable("problems");

            entity.HasKey(p => p.ProblemId);

            entity.Property(p => p.ProblemId)
                .HasColumnName("problem_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(p => p.Title)
                .HasColumnName("title")
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(p => p.Description)
                .HasColumnName("description");

            entity.Property(p => p.Category)
                .HasColumnName("category")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(p => p.Latitude)
                .HasColumnName("latitude")
                .HasPrecision(9, 6)
                .IsRequired();

            entity.Property(p => p.Longitude)
                .HasColumnName("longitude")
                .HasPrecision(9, 6)
                .IsRequired();

            entity.Property(p => p.Address)
                .HasColumnName("address");

            entity.Property(p => p.Priority)
                .HasColumnName("priority")
                .HasMaxLength(20);

            entity.Property(p => p.PriorityScore)
                .HasColumnName("priority_score");

            entity.Property(p => p.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .HasDefaultValue("IDENTIFIED")
                .IsRequired();

            entity.Property(p => p.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(p => p.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // CHECK constraints
            entity.ToTable("problems", table =>
            {
                table.HasCheckConstraint(
                    "chk_problems_category",
                    "\"category\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");

                table.HasCheckConstraint(
                    "chk_problems_priority",
                    "\"priority\" IS NULL OR \"priority\" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')");

                table.HasCheckConstraint(
                    "chk_problems_priority_score",
                    "\"priority_score\" IS NULL OR (\"priority_score\" >= 0 AND \"priority_score\" <= 100)");

                table.HasCheckConstraint(
                    "chk_problems_status",
                    "\"status\" IN ('IDENTIFIED', 'AWAITING_ASSIGNMENT', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')");

                table.HasCheckConstraint(
                    "chk_problems_latitude",
                    "\"latitude\" >= -90 AND \"latitude\" <= 90");

                table.HasCheckConstraint(
                    "chk_problems_longitude",
                    "\"longitude\" >= -180 AND \"longitude\" <= 180");
            });

            // Indexes
            entity.HasIndex(p => p.Status)
                .HasDatabaseName("idx_problems_status");

            entity.HasIndex(p => p.Category)
                .HasDatabaseName("idx_problems_category");

            entity.HasIndex(p => p.Priority)
                .HasDatabaseName("idx_problems_priority");

            entity.HasIndex(p => p.PriorityScore)
                .HasDatabaseName("idx_problems_priority_score");

            entity.HasIndex(p => new { p.Latitude, p.Longitude })
                .HasDatabaseName("idx_problems_location");
        });


        // 7. REPORT PROBLEMS
    
        modelBuilder.Entity<ReportProblem>(entity =>
        {
            entity.ToTable("report_problems");

            entity.HasKey(rp => rp.ReportProblemId);

            entity.Property(rp => rp.ReportProblemId)
                .HasColumnName("report_problem_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(rp => rp.ReportId)
                .HasColumnName("report_id")
                .IsRequired();

            entity.Property(rp => rp.ProblemId)
                .HasColumnName("problem_id")
                .IsRequired();

            entity.Property(rp => rp.LinkType)
                .HasColumnName("link_type")
                .HasMaxLength(30)
                .IsRequired();

            entity.Property(rp => rp.LinkedAt)
                .HasColumnName("linked_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // Report → ReportProblems
            entity.HasOne(rp => rp.Report)
                .WithMany(r => r.ReportProblems)
                .HasForeignKey(rp => rp.ReportId)
                .OnDelete(DeleteBehavior.Cascade);

            // Problem → ReportProblems
            entity.HasOne(rp => rp.Problem)
                .WithMany(p => p.ReportProblems)
                .HasForeignKey(rp => rp.ProblemId)
                .OnDelete(DeleteBehavior.Cascade);

            // UNIQUE(report_id, problem_id)
            entity.HasIndex(rp => new { rp.ReportId, rp.ProblemId })
                .IsUnique()
                .HasDatabaseName("uq_report_problem");

            // CHECK constraint
            entity.ToTable("report_problems", table =>
            {
                table.HasCheckConstraint(
                    "chk_report_problems_link_type",
                    "\"link_type\" IN ('DUPLICATE', 'RELATED', 'PRIMARY')");
            });

            // Indexes
            entity.HasIndex(rp => rp.ReportId)
                .HasDatabaseName("idx_report_problems_report_id");

            entity.HasIndex(rp => rp.ProblemId)
                .HasDatabaseName("idx_report_problems_problem_id");
        });

        
        // 8. WORK ORDERS

        modelBuilder.Entity<WorkOrder>(entity =>
        {
            entity.ToTable("work_orders");

            entity.HasKey(w => w.WorkOrderId);

            entity.Property(w => w.WorkOrderId)
                .HasColumnName("work_order_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(w => w.ProblemId)
                .HasColumnName("problem_id")
                .IsRequired();

            entity.Property(w => w.CrewId)
                .HasColumnName("crew_id")
                .IsRequired();

            entity.Property(w => w.Priority)
                .HasColumnName("priority")
                .HasMaxLength(20)
                .IsRequired();

            entity.Property(w => w.Title)
                .HasColumnName("title")
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(w => w.Instructions)
                .HasColumnName("instructions");

            entity.Property(w => w.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .HasDefaultValue("PENDING_APPROVAL")
                .IsRequired();

            entity.Property(w => w.AssignedAt)
                .HasColumnName("assigned_at");

            entity.Property(w => w.StartedAt)
                .HasColumnName("started_at");

            entity.Property(w => w.CompletedAt)
                .HasColumnName("completed_at");

            entity.Property(w => w.CompletionNotes)
                .HasColumnName("completion_notes");

            entity.Property(w => w.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(w => w.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // Problem → WorkOrders
            entity.HasOne(w => w.Problem)
                .WithMany(p => p.WorkOrders)
                .HasForeignKey(w => w.ProblemId)
                .OnDelete(DeleteBehavior.Restrict);

            // Crew → WorkOrders
            entity.HasOne(w => w.Crew)
                .WithMany(c => c.WorkOrders)
                .HasForeignKey(w => w.CrewId)
                .OnDelete(DeleteBehavior.Restrict);

            // CHECK constraints
            entity.ToTable("work_orders", table =>
            {
                table.HasCheckConstraint(
                    "chk_work_orders_priority",
                    "\"priority\" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')");

                table.HasCheckConstraint(
                    "chk_work_orders_status",
                    "\"status\" IN ('PENDING_APPROVAL', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')");
            });

            // Indexes
            entity.HasIndex(w => w.ProblemId)
                .HasDatabaseName("idx_work_orders_problem_id");

            entity.HasIndex(w => w.CrewId)
                .HasDatabaseName("idx_work_orders_crew_id");

            entity.HasIndex(w => w.Status)
                .HasDatabaseName("idx_work_orders_status");

            entity.HasIndex(w => w.Priority)
                .HasDatabaseName("idx_work_orders_priority");

            entity.HasIndex(w => w.CreatedAt)
                .HasDatabaseName("idx_work_orders_created_at");
        });

        
        // 9. APPROVAL HISTORY

        modelBuilder.Entity<ApprovalHistory>(entity =>
        {
            entity.ToTable("approval_history");

            entity.HasKey(a => a.ApprovalId);

            entity.Property(a => a.ApprovalId)
                .HasColumnName("approval_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(a => a.WorkOrderId)
                .HasColumnName("work_order_id")
                .IsRequired();

            entity.Property(a => a.DecidedBy)
                .HasColumnName("decided_by")
                .IsRequired();

            entity.Property(a => a.Decision)
                .HasColumnName("decision")
                .HasMaxLength(30)
                .IsRequired();

            entity.Property(a => a.Reason)
                .HasColumnName("reason");

            entity.Property(a => a.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // WorkOrder → ApprovalHistory
            entity.HasOne(a => a.WorkOrder)
                .WithMany(w => w.ApprovalHistories)
                .HasForeignKey(a => a.WorkOrderId)
                .OnDelete(DeleteBehavior.Cascade);

            // User → ApprovalHistory
            entity.HasOne(a => a.DecidedByUser)
                .WithMany()
                .HasForeignKey(a => a.DecidedBy)
                .OnDelete(DeleteBehavior.Restrict);

            // CHECK constraint
            entity.ToTable("approval_history", table =>
            {
                table.HasCheckConstraint(
                    "chk_approval_history_decision",
                    "\"decision\" IN ('APPROVED', 'REJECTED', 'REVISION_REQUIRED')");
            });

            // Indexes
            entity.HasIndex(a => a.WorkOrderId)
                .HasDatabaseName("idx_approval_history_work_order_id");

            entity.HasIndex(a => a.DecidedBy)
                .HasDatabaseName("idx_approval_history_decided_by");

            entity.HasIndex(a => a.CreatedAt)
                .HasDatabaseName("idx_approval_history_created_at");
        });


        // 10. WORKFLOW RUNS

        modelBuilder.Entity<WorkflowRun>(entity =>
        {
            entity.ToTable("workflow_runs");

            entity.HasKey(w => w.WorkflowRunId);

            entity.Property(w => w.WorkflowRunId)
                .HasColumnName("workflow_run_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(w => w.ReportId)
                .HasColumnName("report_id")
                .IsRequired();

            entity.Property(w => w.ProblemId)
                .HasColumnName("problem_id");

            entity.Property(w => w.CurrentStage)
                .HasColumnName("current_stage")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(w => w.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .HasDefaultValue("RUNNING")
                .IsRequired();

            entity.Property(w => w.StateData)
                .HasColumnName("state_data")
                .HasColumnType("jsonb");

            entity.Property(w => w.StartedAt)
                .HasColumnName("started_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(w => w.CompletedAt)
                .HasColumnName("completed_at");

            entity.Property(w => w.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(w => w.UpdatedAt)
                .HasColumnName("updated_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            // Report → WorkflowRuns
            entity.HasOne(w => w.Report)
                .WithMany(r => r.WorkflowRuns)
                .HasForeignKey(w => w.ReportId)
                .OnDelete(DeleteBehavior.Cascade);

            // Problem → WorkflowRuns
            entity.HasOne(w => w.Problem)
                .WithMany(p => p.WorkflowRuns)
                .HasForeignKey(w => w.ProblemId)
                .OnDelete(DeleteBehavior.SetNull);

            // CHECK constraints
            entity.ToTable("workflow_runs", table =>
            {
                table.HasCheckConstraint(
                    "chk_workflow_runs_stage",
                    "\"current_stage\" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')");

                table.HasCheckConstraint(
                    "chk_workflow_runs_status",
                    "\"status\" IN ('RUNNING', 'WAITING', 'COMPLETED', 'FAILED', 'CANCELLED')");
            });

            // Indexes
            entity.HasIndex(w => w.ReportId)
                .HasDatabaseName("idx_workflow_runs_report_id");

            entity.HasIndex(w => w.ProblemId)
                .HasDatabaseName("idx_workflow_runs_problem_id");

            entity.HasIndex(w => w.Status)
                .HasDatabaseName("idx_workflow_runs_status");

            entity.HasIndex(w => w.CurrentStage)
                .HasDatabaseName("idx_workflow_runs_current_stage");

            entity.HasIndex(w => w.CreatedAt)
                .HasDatabaseName("idx_workflow_runs_created_at");
        });


        // 11. WORKFLOW EVENTS
        
        modelBuilder.Entity<WorkflowEvent>(entity =>
        {
            entity.ToTable("workflow_events");

            entity.HasKey(w => w.WorkflowEventId);

            entity.Property(w => w.WorkflowEventId)
                .HasColumnName("workflow_event_id")
                .HasDefaultValueSql("gen_random_uuid()");

            entity.Property(w => w.WorkflowRunId)
                .HasColumnName("workflow_run_id")
                .IsRequired();

            entity.Property(w => w.AgentName)
                .HasColumnName("agent_name")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(w => w.Stage)
                .HasColumnName("stage")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(w => w.Status)
                .HasColumnName("status")
                .HasMaxLength(30)
                .IsRequired();

            entity.Property(w => w.InputData)
                .HasColumnName("input_data")
                .HasColumnType("jsonb");

            entity.Property(w => w.OutputData)
                .HasColumnName("output_data")
                .HasColumnType("jsonb");

            entity.Property(w => w.ValidationResult)
                .HasColumnName("validation_result")
                .HasColumnType("jsonb");

            entity.Property(w => w.ToolResults)
                .HasColumnName("tool_results")
                .HasColumnType("jsonb");

            entity.Property(w => w.ErrorMessage)
                .HasColumnName("error_message");

            entity.Property(w => w.StartedAt)
                .HasColumnName("started_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .IsRequired();

            entity.Property(w => w.CompletedAt)
                .HasColumnName("completed_at");

            // WorkflowRun → WorkflowEvents
            entity.HasOne(w => w.WorkflowRun)
                .WithMany(r => r.WorkflowEvents)
                .HasForeignKey(w => w.WorkflowRunId)
                .OnDelete(DeleteBehavior.Cascade);

            // CHECK constraints
            entity.ToTable("workflow_events", table =>
            {
                table.HasCheckConstraint(
                    "chk_workflow_events_stage",
                    "\"stage\" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')");

                table.HasCheckConstraint(
                    "chk_workflow_events_status",
                    "\"status\" IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'WAITING')");
            });

            // Indexes
            entity.HasIndex(w => w.WorkflowRunId)
                .HasDatabaseName("idx_workflow_events_workflow_run_id");

            entity.HasIndex(w => w.AgentName)
                .HasDatabaseName("idx_workflow_events_agent_name");

            entity.HasIndex(w => w.Stage)
                .HasDatabaseName("idx_workflow_events_stage");

            entity.HasIndex(w => w.Status)
                .HasDatabaseName("idx_workflow_events_status");

            entity.HasIndex(w => w.StartedAt)
                .HasDatabaseName("idx_workflow_events_started_at");
        });
    }
}