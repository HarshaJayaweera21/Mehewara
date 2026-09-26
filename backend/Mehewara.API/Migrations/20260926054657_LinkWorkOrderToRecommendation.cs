using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class LinkWorkOrderToRecommendation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "recommendation_id",
                table: "work_orders",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders",
                column: "recommendation_id");

            migrationBuilder.AddForeignKey(
                name: "FK_work_orders_workflow_events_recommendation_id",
                table: "work_orders",
                column: "recommendation_id",
                principalTable: "workflow_events",
                principalColumn: "workflow_event_id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_work_orders_workflow_events_recommendation_id",
                table: "work_orders");

            migrationBuilder.DropIndex(
                name: "idx_work_orders_recommendation_id",
                table: "work_orders");

            migrationBuilder.DropColumn(
                name: "recommendation_id",
                table: "work_orders");
        }
    }
}
