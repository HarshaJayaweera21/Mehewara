namespace Mehewara.API.DTOs.Problems.Consolidation;

public class ProblemConsolidationResultDto
{
    public string Decision { get; set; } = string.Empty; // LINK_EXISTING | CREATE_NEW | UNCERTAIN
    public Guid ReportId { get; set; }
    public Guid? ProblemId { get; set; }
    public List<Guid> RelatedReportIds { get; set; } = new();
    public string Summary { get; set; } = string.Empty;
    public List<string> Evidence { get; set; } = new();
    public NewProblemCandidateDto? NewProblem { get; set; }
}
