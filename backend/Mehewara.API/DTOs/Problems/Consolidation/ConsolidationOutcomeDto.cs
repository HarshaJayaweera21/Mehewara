namespace Mehewara.API.DTOs.Problems.Consolidation;

public class ConsolidationOutcomeDto
{
    public bool Success { get; set; }
    public string Decision { get; set; } = string.Empty;
    public Guid ReportId { get; set; }
    public Guid? ProblemId { get; set; }
    public string ValidationStatus { get; set; } = string.Empty; // PASSED | FAILED | SAFE_FAILURE
    public List<string> ValidationErrors { get; set; } = new();
    public ProblemContextDto? ProblemContext { get; set; }
}
