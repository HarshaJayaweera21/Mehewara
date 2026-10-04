using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityHistory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "activity_history",
                columns: table => new
                {
                    activity_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    actor_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    action = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    recommendation_id = table.Column<Guid>(type: "uuid", nullable: true),
                    work_order_id = table.Column<Guid>(type: "uuid", nullable: true),
                    before_data = table.Column<string>(type: "jsonb", nullable: false),
                    after_data = table.Column<string>(type: "jsonb", nullable: false),
                    note = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_activity_history", x => x.activity_id);
                    table.CheckConstraint("chk_activity_history_action", "action IN ('RECOMMENDATION_EDITED', 'WORK_ORDER_STARTED', 'WORK_ORDER_COMPLETED')");
                    table.CheckConstraint("chk_activity_history_edit_reason", "action <> 'RECOMMENDATION_EDITED' OR NULLIF(BTRIM(note), '') IS NOT NULL");
                    table.CheckConstraint("chk_activity_history_target", "(action = 'RECOMMENDATION_EDITED' AND recommendation_id IS NOT NULL AND work_order_id IS NULL) OR (action IN ('WORK_ORDER_STARTED', 'WORK_ORDER_COMPLETED') AND work_order_id IS NOT NULL AND recommendation_id IS NULL)");
                    table.ForeignKey(
                        name: "FK_activity_history_users_actor_user_id",
                        column: x => x.actor_user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_activity_history_work_orders_work_order_id",
                        column: x => x.work_order_id,
                        principalTable: "work_orders",
                        principalColumn: "work_order_id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_activity_history_workflow_events_recommendation_id",
                        column: x => x.recommendation_id,
                        principalTable: "workflow_events",
                        principalColumn: "workflow_event_id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "idx_activity_history_actor_time",
                table: "activity_history",
                columns: new[] { "actor_user_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "idx_activity_history_recommendation_time",
                table: "activity_history",
                columns: new[] { "recommendation_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "idx_activity_history_work_order_time",
                table: "activity_history",
                columns: new[] { "work_order_id", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "activity_history");
        }
    }
}
