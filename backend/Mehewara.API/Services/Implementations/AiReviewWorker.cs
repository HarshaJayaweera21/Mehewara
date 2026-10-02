namespace Mehewara.API.Services.Implementations;

public class AiReviewWorker(IServiceScopeFactory scopes, ILogger<AiReviewWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                var review = scope.ServiceProvider.GetRequiredService<AiReviewService>();
                var job = await review.ClaimAsync(stoppingToken);
                if (job != null) { await review.ExecuteAsync(job, stoppingToken); continue; }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning("AI review worker unavailable ({Type}); check migrations and service configuration.", ex.GetType().Name); }
            await Task.Delay(TimeSpan.FromSeconds(3), stoppingToken);
        }
    }
}
