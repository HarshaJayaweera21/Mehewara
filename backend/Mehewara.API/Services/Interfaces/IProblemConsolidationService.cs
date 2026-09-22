using Mehewara.API.DTOs.Problems.Consolidation;

namespace Mehewara.API.Services.Interfaces;

public interface IProblemConsolidationService
{
    Task<ConsolidationOutcomeDto> ApplyConsolidationAsync(
        ProblemConsolidationResultDto consolidationResult,
        Guid? workflowRunId = null,
        CancellationToken cancellationToken = default);
}
