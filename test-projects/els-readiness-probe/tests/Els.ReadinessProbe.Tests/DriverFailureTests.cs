using System.Net;
using System.Net.Http.Json;
using System.Net.Sockets;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace Els.ReadinessProbe.Tests;

public sealed class DriverFailureTests
{
    [Fact]
    public async Task RealDriversReportClosedLoopbackPortsAsSeparateFailures()
    {
        // Reserve two distinct ephemeral ports, then close them. Never use a
        // configured server, production credential, Docker or a Kubernetes API.
        var postgresListener = new TcpListener(IPAddress.Loopback, 0);
        var redisListener = new TcpListener(IPAddress.Loopback, 0);
        postgresListener.Start();
        redisListener.Start();
        var postgresPort = ((IPEndPoint)postgresListener.LocalEndpoint).Port;
        var redisPort = ((IPEndPoint)redisListener.LocalEndpoint).Port;
        postgresListener.Stop();
        redisListener.Stop();

        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
                new Dictionary<string, string?>
                {
                    ["Postgres:ConnectionString"] = $"Host=127.0.0.1;Port={postgresPort};Database=unused;Username=unused;Timeout=1;Command Timeout=1",
                    ["Redis:ConnectionString"] = $"127.0.0.1:{redisPort},abortConnect=false,connectTimeout=100,syncTimeout=100,asyncTimeout=100,connectRetry=0",
                    ["Probe:Enabled"] = "false"
                })));
        using var client = factory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(15);
        // Host startup, liveness and statistics do not try to connect.
        Assert.Equal("Healthy", await client.GetStringAsync("/health/liveness"));
        var before = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(0, before!.CompletedRuns);

        using var response = await client.GetAsync("/health/readiness");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var after = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(1, after!.CompletedRuns);
        Assert.All(after.Checks.Values, check =>
        {
            Assert.Equal(1, check.Attempts);
            Assert.Equal(1, check.Unhealthy);
            Assert.Equal(1, check.ErrorRate);
            Assert.NotEmpty(check.LastResult!.Error!.ExceptionTypes);
        });
        Assert.Contains("Npgsql.NpgsqlException",
            after.Checks[Readiness.PostgresCheck].LastResult!.Error!.ExceptionTypes);
        Assert.Contains(after.Checks[Readiness.RedisCheck].LastResult!.Error!.ExceptionTypes,
            name => name.StartsWith("StackExchange.Redis.", StringComparison.Ordinal));
    }
}
