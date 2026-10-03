using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class LinkApprovalHistoryToRecommendation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "work_order_id",
                table: "approval_history",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "recommendation_id",
                table: "approval_history",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "idx_approval_history_recommendation_id",
                table: "approval_history",
                column: "recommendation_id");

            migrationBuilder.AddForeignKey(
                name: "FK_approval_history_workflow_events_recommendation_id",
                table: "approval_history",
                column: "recommendation_id",
                principalTable: "workflow_events",
                principalColumn: "workflow_event_id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM approval_history WHERE work_order_id IS NULL) THEN
                        RAISE EXCEPTION 'Cannot restore a required work_order_id while review records without WorkOrders exist.';
                    END IF;
                END $$;
                """);

            migrationBuilder.DropForeignKey(
                name: "FK_approval_history_workflow_events_recommendation_id",
                table: "approval_history");

            migrationBuilder.DropIndex(
                name: "idx_approval_history_recommendation_id",
                table: "approval_history");

            migrationBuilder.DropColumn(
                name: "recommendation_id",
                table: "approval_history");

            migrationBuilder.AlterColumn<Guid>(
                name: "work_order_id",
                table: "approval_history",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
