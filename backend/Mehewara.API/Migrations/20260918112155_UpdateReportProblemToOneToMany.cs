using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Mehewara.API.Migrations
{
    /// <inheritdoc />
    public partial class UpdateReportProblemToOneToMany : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "report_problems");

            migrationBuilder.AddColumn<Guid>(
                name: "problem_id",
                table: "reports",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "idx_reports_problem_id",
                table: "reports",
                column: "problem_id");

            migrationBuilder.AddForeignKey(
                name: "FK_reports_problems_problem_id",
                table: "reports",
                column: "problem_id",
                principalTable: "problems",
                principalColumn: "problem_id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_reports_problems_problem_id",
                table: "reports");

            migrationBuilder.DropIndex(
                name: "idx_reports_problem_id",
                table: "reports");

            migrationBuilder.DropColumn(
                name: "problem_id",
                table: "reports");

            migrationBuilder.CreateTable(
                name: "report_problems",
                columns: table => new
                {
                    report_problem_id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    problem_id = table.Column<Guid>(type: "uuid", nullable: false),
                    report_id = table.Column<Guid>(type: "uuid", nullable: false),
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
        }
    }
}
