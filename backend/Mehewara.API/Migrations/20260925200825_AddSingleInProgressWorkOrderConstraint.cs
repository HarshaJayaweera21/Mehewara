using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSingleInProgressWorkOrderConstraint : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "idx_work_orders_single_in_progress_crew",
                table: "work_orders",
                column: "crew_id",
                unique: true,
                filter: "\"status\" = 'IN_PROGRESS'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_work_orders_single_in_progress_crew",
                table: "work_orders");
        }
    }
}
