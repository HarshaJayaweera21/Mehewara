using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class ProtectDispatchConcurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders",
                column: "recommendation_id",
                unique: true,
                filter: "recommendation_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ux_work_orders_active_crew",
                table: "work_orders",
                column: "crew_id",
                unique: true,
                filter: "status IN ('ASSIGNED', 'IN_PROGRESS')");

            migrationBuilder.CreateIndex(
                name: "ux_work_orders_active_problem",
                table: "work_orders",
                column: "problem_id",
                unique: true,
                filter: "status IN ('ASSIGNED', 'IN_PROGRESS')");

            migrationBuilder.CreateIndex(
                name: "ux_approval_history_terminal_recommendation",
                table: "approval_history",
                column: "recommendation_id",
                unique: true,
                filter: "recommendation_id IS NOT NULL AND decision IN ('APPROVED', 'REJECTED')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders");

            migrationBuilder.DropIndex(
                name: "ux_work_orders_active_crew",
                table: "work_orders");

            migrationBuilder.DropIndex(
                name: "ux_work_orders_active_problem",
                table: "work_orders");

            migrationBuilder.DropIndex(
                name: "ux_approval_history_terminal_recommendation",
                table: "approval_history");

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders",
                column: "recommendation_id");
        }
    }
}
