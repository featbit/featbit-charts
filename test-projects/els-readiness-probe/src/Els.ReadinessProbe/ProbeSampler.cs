using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Els.ReadinessProbe;

public sealed class ProbeSampler(
    HealthCheckService healthChecks,
    ProbeRecorder recorder,
    IOptions<ProbeOptions> options) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
        {
            return;
        }

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var report = await healthChecks.CheckHealthAsync(Readiness.IsReadiness, stoppingToken);
                recorder.Record(report, "background");
                // One run at a time; delay is measured from the previous completion.
                await Task.Delay(TimeSpan.FromSeconds(options.Value.IntervalSeconds), stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Graceful shutdown; incomplete samples are not recorded as dependency failures.
        }
    }
}
