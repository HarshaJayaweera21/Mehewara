using Mehewara.API.Models;

namespace Mehewara.API.Integrations.AiService;

public interface IAiWorkflowClient
{
    Task<bool> TriggerWorkflowAsync(Report report, Guid workflowRunId);
}
