using Microsoft.Extensions.Configuration;
using Npgsql;
using StackExchange.Redis;

namespace Els.ReadinessProbe.Tests;

public sealed class ConnectionConfigurationTests
{
    [Fact]
    public void MissingConnectionsAreRejectedRatherThanReportingHealthy()
    {
        var error = Assert.Throws<InvalidOperationException>(() =>
            ProbeConnections.FromConfiguration(new ConfigurationBuilder().Build()));
        Assert.Contains("Postgres__ConnectionString", error.Message);
        Assert.Contains("Redis__ConnectionString", error.Message);
    }

    [Fact]
    public void SeparatePasswordsOverrideInlineAndElsRedisDefaultsAreApplied()
    {
        var configuration = Configuration(new()
        {
            ["Postgres:Password"] = "pg-override",
            ["Redis:Password"] = "redis-override"
        });
        var result = ProbeConnections.FromConfiguration(configuration);
        Assert.Equal("pg-override", new NpgsqlConnectionStringBuilder(result.Postgres).Password);
        var redis = ConfigurationOptions.Parse(result.Redis);
        Assert.Equal("redis-override", redis.Password);
        Assert.False(redis.AbortOnConnectFail);
        Assert.Equal(1500, redis.ConnectTimeout);
        Assert.Equal(1500, redis.SyncTimeout);
        Assert.DoesNotContain("override", result.ToString());
    }

    [Fact]
    public void ExplicitRedisOptionsAndPostgresConnectionParametersArePreserved()
    {
        var result = ProbeConnections.FromConfiguration(Configuration(new()
        {
            ["Redis:ConnectionString"] = "localhost:6379,ABORTCONNECT=true,connectTimeout=7000,syncTimeout=8000",
            ["Postgres:ConnectionString"] = "Host=localhost;Database=featbit;Username=test;Timeout=15;Pooling=false;SSL Mode=VerifyFull"
        }));
        var redis = ConfigurationOptions.Parse(result.Redis);
        Assert.True(redis.AbortOnConnectFail);
        Assert.Equal(7000, redis.ConnectTimeout);
        Assert.Equal(8000, redis.SyncTimeout);
        var postgres = new NpgsqlConnectionStringBuilder(result.Postgres);
        Assert.False(postgres.Pooling);
        Assert.Equal(15, postgres.Timeout);
        Assert.Equal(SslMode.VerifyFull, postgres.SslMode);
    }

    private static IConfiguration Configuration(Dictionary<string, string?> overrides)
    {
        var defaults = new Dictionary<string, string?>
        {
            ["Postgres:ConnectionString"] = "Host=localhost;Database=featbit;Username=test;Password=original",
            ["Redis:ConnectionString"] = "localhost:6379,password=original"
        };
        foreach (var (key, value) in overrides) defaults[key] = value;
        return new ConfigurationBuilder().AddInMemoryCollection(defaults).Build();
    }
}
