using System.Net.Sockets;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Els.ReadinessProbe.Tests;

public sealed class RecorderTests
{
    [Fact]
    public void CountersAndLatencyIncludeFailuresAndHistoryIsBounded()
    {
        var recorder = new ProbeRecorder(Options.Create(new ProbeOptions { RecentFailureLimit = 2 }),
            NullLogger<ProbeRecorder>.Instance);
        recorder.Record(Report(HealthStatus.Healthy, 10), "http");
        var firstSnapshot = recorder.Snapshot();
        for (var i = 0; i < 3; i++) recorder.Record(Report(HealthStatus.Unhealthy, 30), "background");
        var snapshot = recorder.Snapshot();
        Assert.Equal(4, snapshot.CompletedRuns);
        Assert.Equal(0.75, snapshot.ReadinessFailureRate);
        Assert.Equal(0.75, snapshot.Checks[Readiness.PostgresCheck].ErrorRate);
        Assert.Equal(25, snapshot.Checks[Readiness.PostgresCheck].MeanDurationMs);
        Assert.Equal(30, snapshot.Checks[Readiness.PostgresCheck].MaxDurationMs);
        Assert.Equal(2, snapshot.RecentFailures.Count);
        Assert.Equal(4, snapshot.RecentFailures[0].Id);
        Assert.Equal(1, firstSnapshot.CompletedRuns);
        Assert.Equal(1, firstSnapshot.Checks[Readiness.PostgresCheck].Attempts);
    }

    [Fact]
    public void DegradedIsAComponentErrorButNotAnHttp503()
    {
        var recorder = new ProbeRecorder(Options.Create(new ProbeOptions()), NullLogger<ProbeRecorder>.Instance);
        recorder.Record(Report(HealthStatus.Degraded, 20), "http");
        var snapshot = recorder.Snapshot();
        Assert.Equal(0, snapshot.ReadinessFailureRate);
        Assert.Equal(1, snapshot.Checks[Readiness.PostgresCheck].ErrorRate);
        Assert.Equal(1, snapshot.Checks[Readiness.PostgresCheck].Degraded);
    }

    [Fact]
    public void ErrorMetadataKeepsNestedTypesAndCodesWithoutMessages()
    {
        var exception = new AggregateException("Password=do-not-echo",
            new PostgresException("do-not-echo", "ERROR", "ERROR", "08001"),
            new IOException("do-not-echo", new SocketException((int)SocketError.ConnectionRefused)));
        var error = ErrorDetails.FromException(exception)!;
        Assert.Equal("08001", error.SqlState);
        Assert.Equal(nameof(SocketError.ConnectionRefused), error.SocketError);
        Assert.Contains(typeof(SocketException).FullName!, error.ExceptionTypes);
        Assert.DoesNotContain("do-not-echo", System.Text.Json.JsonSerializer.Serialize(error));
    }

    private static HealthReport Report(HealthStatus status, double durationMs) => new(
        new Dictionary<string, HealthReportEntry>
        {
            [Readiness.PostgresCheck] = new(status, null, TimeSpan.FromMilliseconds(durationMs), null, null),
            [Readiness.RedisCheck] = new(HealthStatus.Healthy, null, TimeSpan.FromMilliseconds(1), null, null)
        }, TimeSpan.FromMilliseconds(durationMs));
}
