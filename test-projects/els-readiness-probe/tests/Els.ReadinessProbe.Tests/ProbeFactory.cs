using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Els.ReadinessProbe.Tests;

internal sealed class ProbeFactory(Func<HealthCheckResult>? postgres = null,
    bool background = false) : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Postgres:ConnectionString"] = "Host=127.0.0.1;Database=unused;Username=unused",
                ["Redis:ConnectionString"] = "127.0.0.1:6379",
                ["Probe:Enabled"] = background.ToString(),
                ["Probe:IntervalSeconds"] = "0.1"
            }));
        builder.ConfigureTestServices(services => services.PostConfigure<HealthCheckServiceOptions>(options =>
        {
            // No real connections in HTTP contract tests. Driver failure behavior
            // is checked separately against closed loopback ports.
            options.Registrations.Clear();
            options.Registrations.Add(new HealthCheckRegistration(Readiness.PostgresCheck,
                _ => new DelegateCheck(postgres ?? (() => HealthCheckResult.Healthy())),
                HealthStatus.Unhealthy, [Readiness.Tag]));
            options.Registrations.Add(new HealthCheckRegistration(Readiness.RedisCheck,
                _ => new DelegateCheck(() => HealthCheckResult.Healthy()),
                HealthStatus.Unhealthy, [Readiness.Tag]));
        }));
    }

    private sealed class DelegateCheck(Func<HealthCheckResult> result) : IHealthCheck
    {
        public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context,
            CancellationToken cancellationToken = default) => Task.FromResult(result());
    }
}
