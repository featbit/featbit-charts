using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;
using StackExchange.Redis;

namespace Els.ReadinessProbe;

public static class Readiness
{
    public const string Tag = "Readiness";
    public const string PostgresCheck = "npgsql";
    public const string RedisCheck = "redis";

    public static bool IsReadiness(HealthCheckRegistration registration) =>
        registration.Tags.Contains(Tag);

    public static IServiceCollection AddElsReadiness(this IServiceCollection services)
    {
        services.AddSingleton(sp => ProbeConnections.FromConfiguration(sp.GetRequiredService<IConfiguration>()));
        // Keep one pooled data source, like ELS. Defer construction until the
        // finalized host configuration is available; building it does no I/O.
        services.AddSingleton(sp => new NpgsqlDataSourceBuilder(sp.GetRequiredService<ProbeConnections>().Postgres)
            .UseLoggerFactory(sp.GetRequiredService<ILoggerFactory>()).Build());
        services.AddSingleton(sp => new RedisConnection(sp.GetRequiredService<ProbeConnections>().Redis));
        services.AddHealthChecks()
            .AddNpgSql(name: PostgresCheck, tags: [Tag])
            .AddRedis(sp => sp.GetRequiredService<RedisConnection>().Connection,
                name: RedisCheck, tags: [Tag], timeout: TimeSpan.FromSeconds(5));
        return services;
    }
}

public sealed record ProbeConnections(string Postgres, string Redis)
{
    public static bool IsValid(IConfiguration configuration)
    {
        try
        {
            FromConfiguration(configuration);
            return true;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }

    public static ProbeConnections FromConfiguration(IConfiguration configuration)
    {
        var postgres = configuration["Postgres:ConnectionString"];
        var redis = configuration["Redis:ConnectionString"];
        if (string.IsNullOrWhiteSpace(postgres) || string.IsNullOrWhiteSpace(redis))
        {
            throw new InvalidOperationException(
                "Set Postgres__ConnectionString and Redis__ConnectionString before starting the probe.");
        }

        NpgsqlConnectionStringBuilder postgresOptions;
        ConfigurationOptions redisOptions;
        try
        {
            postgresOptions = new NpgsqlConnectionStringBuilder(postgres);
            redisOptions = ConfigurationOptions.Parse(redis);
        }
        catch (ArgumentException)
        {
            // Do not include connection strings or parser exceptions in startup logs.
            throw new InvalidOperationException("Invalid PostgreSQL or Redis connection string; check local configuration.");
        }

        if (!string.IsNullOrWhiteSpace(configuration["Postgres:Password"]))
        {
            postgresOptions.Password = configuration["Postgres:Password"];
        }
        if (!string.IsNullOrWhiteSpace(configuration["Redis:Password"]))
        {
            redisOptions.Password = configuration["Redis:Password"];
        }

        // Mirror ELS RedisClient.EnsureSelfHealingOptions. Explicit tokens win.
        var redisConnectionString = redisOptions.ToString(includePassword: true);
        if (!HasOption(redisConnectionString, "abortConnect"))
        {
            redisConnectionString += ",abortConnect=false";
        }
        if (!HasOption(redisConnectionString, "connectTimeout"))
        {
            redisConnectionString += $",connectTimeout={configuration.GetValue("Redis:ConnectTimeoutMs", 1500)}";
        }
        if (!HasOption(redisConnectionString, "syncTimeout"))
        {
            redisConnectionString += $",syncTimeout={configuration.GetValue("Redis:SyncTimeoutMs", 1500)}";
        }
        return new ProbeConnections(postgresOptions.ConnectionString, redisConnectionString);
    }

    private static bool HasOption(string connectionString, string name) => connectionString.Split(',')
        .Any(token => token.TrimStart().StartsWith(name + "=", StringComparison.OrdinalIgnoreCase));

    // Avoid record-generated ToString() exposing credentials in diagnostics/debug logs.
    public override string ToString() => "ProbeConnections { Postgres = [redacted], Redis = [redacted] }";
}

public sealed class RedisConnection : IDisposable
{
    private readonly Lazy<ConnectionMultiplexer> _connection;

    public RedisConnection(string connectionString) =>
        _connection = new Lazy<ConnectionMultiplexer>(() => ConnectionMultiplexer.Connect(connectionString));

    public IConnectionMultiplexer Connection => _connection.Value;

    public void Dispose()
    {
        if (_connection.IsValueCreated)
        {
            _connection.Value.Dispose();
        }
    }
}
