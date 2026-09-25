using Mehewara.API.Common;
using Mehewara.API.DTOs.Problems;
using Mehewara.API.DTOs.Problems.Consolidation;

namespace Mehewara.API.Services.Interfaces;

public interface IProblemService
{
    Task<ProblemResponse> CreateProblemAsync(CreateProblemRequest request);
    Task<PagedResult<ProblemResponse>> GetProblemsAsync(GetProblemsQuery query);
    Task<ProblemDetailResponse> GetProblemByIdAsync(Guid id);
    Task<IEnumerable<ProblemReportResponse>> GetReportsByProblemIdAsync(Guid problemId);

    // Coordinator Human-in-the-Loop Triage for UNCERTAIN reports
    Task<List<UncertainReportResponse>> GetUncertainReportsAsync();
    Task<ProblemResponse> LinkUncertainReportAsync(LinkUncertainReportRequest request);
    Task<ProblemResponse> CreateProblemFromUncertainReportAsync(CreateProblemFromUncertainReportRequest request);
}