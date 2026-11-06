using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Els.ReadinessProbe.Tests;

public sealed class EndpointTests
{
    [Fact]
    public async Task LivenessAndStatisticsDoNotRunDependencyChecks()
    {
        using var factory = new ProbeFactory(() => throw new InvalidOperationException("Should not run"));
        using var client = factory.CreateClient();
        Assert.Equal("Healthy", await client.GetStringAsync("/health/liveness"));
        var stats = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(0, stats!.CompletedRuns);
        Assert.All(stats.Checks.Values, check => Assert.Equal(0, check.Attempts));
    }

    [Fact]
    public async Task ReadinessReturnsHealthyAndRecordsBothDependencies()
    {
        using var factory = new ProbeFactory();
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/health/readiness");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
        Assert.Equal("text/plain", response.Content.Headers.ContentType!.MediaType);
        Assert.Contains("no-store", response.Headers.CacheControl!.ToString());
        var stats = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(1, stats!.CompletedRuns);
        Assert.Equal(1, stats.RunsBySource["http"]);
        Assert.All(stats.Checks.Values, check =>
        {
            Assert.Equal(1, check.Attempts);
            Assert.Equal(1, check.Healthy);
            Assert.Equal(0, check.ErrorRate);
        });
    }

    [Fact]
    public async Task FailureReturns503AndKeepsSeparatePgAndRedisErrorRates()
    {
        var calls = 0;
        using var factory = new ProbeFactory(() => Interlocked.Increment(ref calls) == 1
            ? HealthCheckResult.Healthy()
            : HealthCheckResult.Unhealthy("Password=do-not-echo",
                new TimeoutException("Password=do-not-echo")));
        using var client = factory.CreateClient();
        Assert.Equal("Healthy", await client.GetStringAsync("/health/readiness"));
        using var failed = await client.GetAsync("/health/readiness");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, failed.StatusCode);
        Assert.Equal("Unhealthy", await failed.Content.ReadAsStringAsync());

        var json = await client.GetStringAsync("/diagnostics/stats");
        Assert.DoesNotContain("do-not-echo", json);
        var stats = System.Text.Json.JsonSerializer.Deserialize<StatisticsSnapshot>(json,
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;
        Assert.Equal(0.5, stats.ReadinessFailureRate);
        Assert.Equal(0.5, stats.Checks[Readiness.PostgresCheck].ErrorRate);
        Assert.Equal(0, stats.Checks[Readiness.RedisCheck].ErrorRate);
        Assert.Single(stats.RecentFailures);
        Assert.Contains(typeof(TimeoutException).FullName!,
            stats.RecentFailures[0].Checks[Readiness.PostgresCheck].Error!.ExceptionTypes);
    }

    [Fact]
    public async Task ConcurrentHttpSamplesDoNotLoseCounts()
    {
        using var factory = new ProbeFactory();
        using var client = factory.CreateClient();
        await Task.WhenAll(Enumerable.Range(0, 64).Select(async _ =>
        {
            using var response = await client.GetAsync("/health/readiness");
            response.EnsureSuccessStatusCode();
        }));
        var stats = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(64, stats!.CompletedRuns);
        Assert.All(stats.Checks.Values, check => Assert.Equal(64, check.Attempts));
    }

    [Fact]
    public async Task BackgroundSamplingIsOptInAndRecordsItsSource()
    {
        using var factory = new ProbeFactory(background: true);
        using var client = factory.CreateClient();
        StatisticsSnapshot? stats = null;
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        while (!deadline.IsCancellationRequested)
        {
            stats = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats", deadline.Token);
            if (stats!.CompletedRuns >= 2) break;
            await Task.Delay(20, deadline.Token);
        }
        Assert.True(stats!.CompletedRuns >= 2);
        Assert.Equal(stats.CompletedRuns, stats.RunsBySource["background"]);
        Assert.False(stats.RunsBySource.ContainsKey("http"));
    }
}
