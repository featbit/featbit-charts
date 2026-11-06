using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

namespace Els.ReadinessProbe.Tests;

public sealed class StartupValidationTests
{
    [Theory]
    [InlineData("Postgres:ConnectionString", "")]
    [InlineData("Redis:ConnectionString", "")]
    [InlineData("Probe:IntervalSeconds", "0")]
    public void InvalidSettingsFailAtHostStartup(string key, string value)
    {
        var settings = new Dictionary<string, string?>
        {
            ["Postgres:ConnectionString"] = "Host=127.0.0.1;Database=unused;Username=unused",
            ["Redis:ConnectionString"] = "127.0.0.1:6379",
            ["Probe:Enabled"] = "false",
            [key] = value
        };
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(settings)));
        Assert.Throws<OptionsValidationException>(() => factory.CreateClient());
    }
}
