using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    public partial class InitialCreate : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "problems",
                columns: table => new
                {
                    problem_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    address = table.Column<string>(type: "text", nullable: true),
                    priority = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    priority_score = table.Column<int>(type: "integer", nullable: true),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false, defaultValue: "IDENTIFIED"),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_problems", x => x.problem_id);
                    table.CheckConstraint("chk_problems_category", "\"category\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");
                    table.CheckConstraint("chk_problems_latitude", "\"latitude\" >= -90 AND \"latitude\" <= 90");
                    table.CheckConstraint("chk_problems_longitude", "\"longitude\" >= -180 AND \"longitude\" <= 180");
                    table.CheckConstraint("chk_problems_priority", "\"priority\" IS NULL OR \"priority\" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')");
                    table.CheckConstraint("chk_problems_priority_score", "\"priority_score\" IS NULL OR (\"priority_score\" >= 0 AND \"priority_score\" <= 100)");
                    table.CheckConstraint("chk_problems_status", "\"status\" IN ('IDENTIFIED', 'AWAITING_ASSIGNMENT', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')");
                });

            migrationBuilder.CreateTable(
                name: "roles",
                columns: table => new
                {
                    role_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    role_name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    role_code = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    description = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_roles", x => x.role_id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    role_id = table.Column<Guid>(type: "uuid", nullable: false),
                    first_name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    last_name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    email = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    password_hash = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    phone_number = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.user_id);
                    table.ForeignKey(
                        name: "FK_users_roles_role_id",
                        column: x => x.role_id,
                        principalTable: "roles",
                        principalColumn: "role_id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "crews",
                columns: table => new
                {
                    crew_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    crew_name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    crew_type = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    crew_leader_user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    contact_number = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false, defaultValue: "AVAILABLE"),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_crews", x => x.crew_id);
                    table.CheckConstraint("chk_crews_status", "\"status\" IN ('AVAILABLE', 'BUSY', 'UNAVAILABLE')");
                    table.CheckConstraint("chk_crews_type", "\"crew_type\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");
                    table.ForeignKey(
                        name: "FK_crews_users_crew_leader_user_id",
                        column: x => x.crew_leader_user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "reports",
                columns: table => new
                {
                    report_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    resident_id = table.Column<Guid>(type: "uuid", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    address = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false, defaultValue: "PENDING"),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_reports", x => x.report_id);
                    table.CheckConstraint("chk_reports_category", "\"category\" IN ('DRAINAGE', 'ROAD', 'WASTE', 'ELECTRICAL', 'ENVIRONMENT')");
                    table.CheckConstraint("chk_reports_latitude", "\"latitude\" >= -90 AND \"latitude\" <= 90");
                    table.CheckConstraint("chk_reports_longitude", "\"longitude\" >= -180 AND \"longitude\" <= 180");
                    table.CheckConstraint("chk_reports_status", "\"status\" IN ('PENDING', 'PROCESSING', 'ASSIGNED', 'RESOLVED', 'CANCELLED')");
                    table.ForeignKey(
                        name: "FK_reports_users_resident_id",
                        column: x => x.resident_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "work_orders",
                columns: table => new
                {
                    work_order_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    problem_id = table.Column<Guid>(type: "uuid", nullable: false),
                    crew_id = table.Column<Guid>(type: "uuid", nullable: false),
                    priority = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    instructions = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false, defaultValue: "PENDING_APPROVAL"),
                    assigned_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    started_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    completed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    completion_notes = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_work_orders", x => x.work_order_id);
                    table.CheckConstraint("chk_work_orders_priority", "\"priority\" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')");
                    table.CheckConstraint("chk_work_orders_status", "\"status\" IN ('PENDING_APPROVAL', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')");
                    table.ForeignKey(
                        name: "FK_work_orders_crews_crew_id",
                        column: x => x.crew_id,
                        principalTable: "crews",
                        principalColumn: "crew_id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_work_orders_problems_problem_id",
                        column: x => x.problem_id,
                        principalTable: "problems",
                        principalColumn: "problem_id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "report_photos",
                columns: table => new
                {
                    photo_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    report_id = table.Column<Guid>(type: "uuid", nullable: false),
                    photo_url = table.Column<string>(type: "text", nullable: false),
                    file_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    mime_type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    uploaded_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_photos", x => x.photo_id);
                    table.ForeignKey(
                        name: "FK_report_photos_reports_report_id",
                        column: x => x.report_id,
                        principalTable: "reports",
                        principalColumn: "report_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "report_problems",
                columns: table => new
                {
                    report_problem_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    report_id = table.Column<Guid>(type: "uuid", nullable: false),
                    problem_id = table.Column<Guid>(type: "uuid", nullable: false),
                    link_type = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    linked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_problems", x => x.report_problem_id);
                    table.CheckConstraint("chk_report_problems_link_type", "\"link_type\" IN ('DUPLICATE', 'RELATED', 'PRIMARY')");
                    table.ForeignKey(
                        name: "FK_report_problems_problems_problem_id",
                        column: x => x.problem_id,
                        principalTable: "problems",
                        principalColumn: "problem_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_report_problems_reports_report_id",
                        column: x => x.report_id,
                        principalTable: "reports",
                        principalColumn: "report_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "workflow_runs",
                columns: table => new
                {
                    workflow_run_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    report_id = table.Column<Guid>(type: "uuid", nullable: false),
                    problem_id = table.Column<Guid>(type: "uuid", nullable: true),
                    current_stage = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false, defaultValue: "RUNNING"),
                    state_data = table.Column<string>(type: "jsonb", nullable: true),
                    started_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    completed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_workflow_runs", x => x.workflow_run_id);
                    table.CheckConstraint("chk_workflow_runs_stage", "\"current_stage\" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')");
                    table.CheckConstraint("chk_workflow_runs_status", "\"status\" IN ('RUNNING', 'WAITING', 'COMPLETED', 'FAILED', 'CANCELLED')");
                    table.ForeignKey(
                        name: "FK_workflow_runs_problems_problem_id",
                        column: x => x.problem_id,
                        principalTable: "problems",
                        principalColumn: "problem_id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_workflow_runs_reports_report_id",
                        column: x => x.report_id,
                        principalTable: "reports",
                        principalColumn: "report_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "approval_history",
                columns: table => new
                {
                    approval_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    work_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    decided_by = table.Column<Guid>(type: "uuid", nullable: false),
                    decision = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    reason = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_approval_history", x => x.approval_id);
                    table.CheckConstraint("chk_approval_history_decision", "\"decision\" IN ('APPROVED', 'REJECTED', 'REVISION_REQUIRED')");
                    table.ForeignKey(
                        name: "FK_approval_history_users_decided_by",
                        column: x => x.decided_by,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_approval_history_work_orders_work_order_id",
                        column: x => x.work_order_id,
                        principalTable: "work_orders",
                        principalColumn: "work_order_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "workflow_events",
                columns: table => new
                {
                    workflow_event_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    workflow_run_id = table.Column<Guid>(type: "uuid", nullable: false),
                    agent_name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    stage = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    input_data = table.Column<string>(type: "jsonb", nullable: true),
                    output_data = table.Column<string>(type: "jsonb", nullable: true),
                    validation_result = table.Column<string>(type: "jsonb", nullable: true),
                    tool_results = table.Column<string>(type: "jsonb", nullable: true),
                    error_message = table.Column<string>(type: "text", nullable: true),
                    started_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    completed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_workflow_events", x => x.workflow_event_id);
                    table.CheckConstraint("chk_workflow_events_stage", "\"stage\" IN ('REPORT_ANALYSIS', 'PROBLEM_CONSOLIDATION', 'PRIORITIZATION', 'VALIDATION', 'WAITING_FOR_APPROVAL', 'WORK_EXECUTION', 'COMPLETED')");
                    table.CheckConstraint("chk_workflow_events_status", "\"status\" IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'WAITING')");
                    table.ForeignKey(
                        name: "FK_workflow_events_workflow_runs_workflow_run_id",
                        column: x => x.workflow_run_id,
                        principalTable: "workflow_runs",
                        principalColumn: "workflow_run_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "idx_approval_history_created_at",
                table: "approval_history",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "idx_approval_history_decided_by",
                table: "approval_history",
                column: "decided_by");

            migrationBuilder.CreateIndex(
                name: "idx_approval_history_work_order_id",
                table: "approval_history",
                column: "work_order_id");

            migrationBuilder.CreateIndex(
                name: "idx_crews_leader",
                table: "crews",
                column: "crew_leader_user_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_crews_status",
                table: "crews",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "idx_crews_type",
                table: "crews",
                column: "crew_type");

            migrationBuilder.CreateIndex(
                name: "IX_crews_crew_name",
                table: "crews",
                column: "crew_name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_problems_category",
                table: "problems",
                column: "category");

            migrationBuilder.CreateIndex(
                name: "idx_problems_location",
                table: "problems",
                columns: new[] { "latitude", "longitude" });

            migrationBuilder.CreateIndex(
                name: "idx_problems_priority",
                table: "problems",
                column: "priority");

            migrationBuilder.CreateIndex(
                name: "idx_problems_priority_score",
                table: "problems",
                column: "priority_score");

            migrationBuilder.CreateIndex(
                name: "idx_problems_status",
                table: "problems",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "idx_report_photos_report_id",
                table: "report_photos",
                column: "report_id");

            migrationBuilder.CreateIndex(
                name: "idx_report_problems_problem_id",
                table: "report_problems",
                column: "problem_id");

            migrationBuilder.CreateIndex(
                name: "idx_report_problems_report_id",
                table: "report_problems",
                column: "report_id");

            migrationBuilder.CreateIndex(
                name: "uq_report_problem",
                table: "report_problems",
                columns: new[] { "report_id", "problem_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_reports_category",
                table: "reports",
                column: "category");

            migrationBuilder.CreateIndex(
                name: "idx_reports_created_at",
                table: "reports",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "idx_reports_location",
                table: "reports",
                columns: new[] { "latitude", "longitude" });

            migrationBuilder.CreateIndex(
                name: "idx_reports_resident_id",
                table: "reports",
                column: "resident_id");

            migrationBuilder.CreateIndex(
                name: "idx_reports_status",
                table: "reports",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "IX_roles_role_code",
                table: "roles",
                column: "role_code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_roles_role_name",
                table: "roles",
                column: "role_name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_users_active",
                table: "users",
                column: "is_active");

            migrationBuilder.CreateIndex(
                name: "idx_users_role_id",
                table: "users",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "IX_users_email",
                table: "users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_created_at",
                table: "work_orders",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_crew_id",
                table: "work_orders",
                column: "crew_id");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_priority",
                table: "work_orders",
                column: "priority");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_problem_id",
                table: "work_orders",
                column: "problem_id");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_status",
                table: "work_orders",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_events_agent_name",
                table: "workflow_events",
                column: "agent_name");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_events_stage",
                table: "workflow_events",
                column: "stage");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_events_started_at",
                table: "workflow_events",
                column: "started_at");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_events_status",
                table: "workflow_events",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_events_workflow_run_id",
                table: "workflow_events",
                column: "workflow_run_id");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_runs_created_at",
                table: "workflow_runs",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_runs_current_stage",
                table: "workflow_runs",
                column: "current_stage");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_runs_problem_id",
                table: "workflow_runs",
                column: "problem_id");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_runs_report_id",
                table: "workflow_runs",
                column: "report_id");

            migrationBuilder.CreateIndex(
                name: "idx_workflow_runs_status",
                table: "workflow_runs",
                column: "status");

            // PostgreSQL updated_at trigger

            migrationBuilder.Sql(@"
                CREATE OR REPLACE FUNCTION update_updated_at_column()
                RETURNS TRIGGER AS $$
                BEGIN
                    NEW.updated_at = CURRENT_TIMESTAMP;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_roles_updated_at
                BEFORE UPDATE ON roles
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_users_updated_at
                BEFORE UPDATE ON users
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_crews_updated_at
                BEFORE UPDATE ON crews
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_reports_updated_at
                BEFORE UPDATE ON reports
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_problems_updated_at
                BEFORE UPDATE ON problems
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_work_orders_updated_at
                BEFORE UPDATE ON work_orders
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            migrationBuilder.Sql(@"
                CREATE TRIGGER trg_workflow_runs_updated_at
                BEFORE UPDATE ON workflow_runs
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
            ");

            // Seed initial roles

            migrationBuilder.Sql(@"
                INSERT INTO roles (role_name, role_code, description, is_active)
                VALUES
                    ('Resident', 'RESIDENT', 'Municipal resident who submits and tracks reports', TRUE),
                    ('Administrator', 'ADMIN', 'Coordinator/administrator who reviews AI recommendations and manages workflows', TRUE),
                    ('Drainage Crew Leader', 'CREW_LEADER_DRAINAGE', NULL, TRUE),
                    ('Waste Crew Leader', 'CREW_LEADER_WASTE', NULL, TRUE),
                    ('Road Crew Leader', 'CREW_LEADER_ROAD', NULL, TRUE),
                    ('Electrical Crew Leader', 'CREW_LEADER_ELECTRICAL', NULL, TRUE)
                ON CONFLICT (role_code) DO NOTHING;
            ");

        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {

            // Remove PostgreSQL triggers and function before dropping tables.
            migrationBuilder.Sql(@"
                DROP TRIGGER IF EXISTS trg_roles_updated_at ON roles;
                DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
                DROP TRIGGER IF EXISTS trg_crews_updated_at ON crews;
                DROP TRIGGER IF EXISTS trg_reports_updated_at ON reports;
                DROP TRIGGER IF EXISTS trg_problems_updated_at ON problems;
                DROP TRIGGER IF EXISTS trg_work_orders_updated_at ON work_orders;
                DROP TRIGGER IF EXISTS trg_workflow_runs_updated_at ON workflow_runs;

                DROP FUNCTION IF EXISTS update_updated_at_column();
            ");

            migrationBuilder.DropTable(
                name: "approval_history");

            migrationBuilder.DropTable(
                name: "report_photos");

            migrationBuilder.DropTable(
                name: "report_problems");

            migrationBuilder.DropTable(
                name: "workflow_events");

            migrationBuilder.DropTable(
                name: "work_orders");

            migrationBuilder.DropTable(
                name: "workflow_runs");

            migrationBuilder.DropTable(
                name: "crews");

            migrationBuilder.DropTable(
                name: "problems");

            migrationBuilder.DropTable(
                name: "reports");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropTable(
                name: "roles");
        }
    }
}