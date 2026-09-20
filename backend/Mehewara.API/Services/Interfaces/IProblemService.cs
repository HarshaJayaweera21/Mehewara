using Mehewara.API.Common;
using Mehewara.API.DTOs.Problems;

namespace Mehewara.API.Services.Interfaces;

public interface IProblemService
{
    Task<ProblemResponse> CreateProblemAsync(CreateProblemRequest request);
    Task<PagedResult<ProblemResponse>> GetProblemsAsync(GetProblemsQuery query);
}