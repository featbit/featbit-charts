using System.Diagnostics;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Els.ReadinessProbe;

public sealed class ProbeSampler(
    HealthCheckService healthChecks,
    ProbeRecorder recorder,
    IOptions<ProbeOptions> options,
    ILogger<ProbeSampler> logger) : BackgroundService
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
                await SampleAsync(stoppingToken);
                // One run at a time; delay is measured from the previous completion.
                await Task.Delay(TimeSpan.FromSeconds(options.Value.IntervalSeconds), stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Graceful shutdown; incomplete samples are not recorded as dependency failures.
        }
    }

    private async Task SampleAsync(CancellationToken stoppingToken)
    {
        var previous = Activity.Current;
        try
        {
            // Each scheduled sample is an independent trace, even if host startup had an ambient activity.
            Activity.Current = null;
            using var activity = new Activity("Readiness.Background").SetIdFormat(ActivityIdFormat.W3C).Start();
            using var scope = logger.BeginScope(new Dictionary<string, object?> { ["Source"] = "background" });
            logger.LogInformation(new EventId(1100, "ReadinessBackgroundStarted"),
                "Readiness background sample started TraceId={TraceId} SpanId={SpanId} Source={Source}",
                activity.TraceId.ToString(), activity.SpanId.ToString(), "background");
            try
            {
                var report = await healthChecks.CheckHealthAsync(Readiness.IsReadiness, stoppingToken);
                recorder.Record(report, "background");
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                logger.LogInformation(new EventId(1105, "ReadinessBackgroundCanceled"),
                    "Readiness background sample canceled TraceId={TraceId} SpanId={SpanId} Source={Source}",
                    activity.TraceId.ToString(), activity.SpanId.ToString(), "background");
                throw;
            }
        }
        finally
        {
            Activity.Current = previous;
        }
    }
}
