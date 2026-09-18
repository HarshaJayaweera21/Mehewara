using Mehewara.API.DTOs.Problems;

namespace Mehewara.API.Services.Interfaces;

public interface IProblemService
{
    Task<ProblemResponse> CreateProblemAsync(CreateProblemRequest request);
}