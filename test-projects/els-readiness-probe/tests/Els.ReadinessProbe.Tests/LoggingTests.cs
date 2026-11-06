using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

namespace Els.ReadinessProbe.Tests;

public sealed class LoggingTests
{
    [Fact]
    public async Task HttpLogsAndResponseShareIncomingW3CTraceAndIncludeHealthyDependencies()
    {
        const string traceId = "0123456789abcdef0123456789abcdef";
        using var logs = new CapturedLogs();
        using var factory = new ProbeFactory().WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddSingleton<ILoggerProvider>(logs)));
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/health/readiness?password=DO-NOT-LOG-QUERY");
        request.Headers.Add("traceparent", $"00-{traceId}-0123456789abcdef-01");
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(traceId, response.Headers.GetValues("X-Trace-Id").Single());
        Assert.Equal("1", response.Headers.GetValues("X-Probe-Sample-Id").Single());
        var entries = logs.ReadinessEntries();
        Assert.Single(entries, entry => entry.Event.Name == "ReadinessRequestStarted");
        Assert.Single(entries, entry => entry.Event.Name == "ReadinessRequestCompleted");
        Assert.Single(entries, entry => entry.Event.Name == "ReadinessSampleCompleted");
        var dependencies = entries.Where(entry => entry.Event.Name == "ReadinessDependencyCompleted").ToArray();
        Assert.Equal(2, dependencies.Length);
        Assert.Contains(dependencies, entry => Equals(entry.State["Check"], Readiness.PostgresCheck));
        Assert.Contains(dependencies, entry => Equals(entry.State["Check"], Readiness.RedisCheck));
        Assert.All(entries, entry =>
        {
            Assert.Equal(traceId, entry.State["TraceId"]);
            Assert.Matches("^[0-9a-f]{16}$", (string)entry.State["SpanId"]!);
            Assert.Equal("http", entry.State["Source"]);
            Assert.False(string.IsNullOrWhiteSpace((string?)entry.State["RequestId"]));
        });
        Assert.All(dependencies, entry =>
        {
            Assert.Equal("Healthy", entry.State["Status"]);
            Assert.Equal(LogLevel.Information, entry.Level);
            Assert.True((double)entry.State["DurationMs"]! >= 0);
        });
        Assert.DoesNotContain("DO-NOT-LOG-QUERY", JsonSerializer.Serialize(entries));
    }

    [Fact]
    public async Task FailedDependencyLogsCodesAndStackFramesWithoutRawExceptionMessages()
    {
        using var logs = new CapturedLogs();
        using var factory = new ProbeFactory(() => HealthCheckResult.Unhealthy("DO-NOT-LOG-SECRET", Failure()))
            .WithWebHostBuilder(builder => builder.ConfigureServices(services => services.AddSingleton<ILoggerProvider>(logs)));
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/health/readiness");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var traceId = response.Headers.GetValues("X-Trace-Id").Single();
        var entries = logs.ReadinessEntries();
        var errors = entries.Where(entry => entry.Event.Name == "ReadinessDependencyException").ToArray();
        Assert.Equal(2, errors.Length);
        Assert.All(errors, entry =>
        {
            Assert.Equal(traceId, entry.State["TraceId"]);
            Assert.Equal(Readiness.PostgresCheck, entry.State["Check"]);
            Assert.Equal(LogLevel.Warning, entry.Level);
            Assert.NotNull(entry.State["HResult"]);
            Assert.Null(entry.Exception);
        });
        Assert.Contains(errors, entry => entry.State["StackTrace"] is string stack && stack.Contains(nameof(Failure)));
        Assert.Contains(errors, entry => Equals(entry.State["SocketError"], nameof(SocketError.ConnectionRefused)));
        Assert.Single(entries, entry => entry.Event.Name == "ReadinessRequestCompleted" && Equals(entry.State["HttpStatusCode"], 503));
        Assert.DoesNotContain("DO-NOT-LOG-SECRET", JsonSerializer.Serialize(entries));
        var stats = await client.GetFromJsonAsync<StatisticsSnapshot>("/diagnostics/stats");
        Assert.Equal(traceId, Assert.Single(stats!.RecentFailures).TraceId);
    }

    [Fact]
    public async Task BackgroundSamplesHaveDistinctTracesAndSeparateSource()
    {
        using var ambient = new Activity("TestHostStartup").SetIdFormat(ActivityIdFormat.W3C).Start();
        using var logs = new CapturedLogs();
        using var factory = new ProbeFactory(background: true).WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddSingleton<ILoggerProvider>(logs)));
        using var client = factory.CreateClient();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        CapturedEntry[] samples;
        do
        {
            await client.GetAsync("/health/liveness", deadline.Token);
            samples = logs.ReadinessEntries().Where(entry => entry.Event.Name == "ReadinessSampleCompleted").ToArray();
            if (samples.Length < 2) await Task.Delay(20, deadline.Token);
        } while (samples.Length < 2);
        Assert.Equal(samples.Length, samples.Select(entry => entry.State["TraceId"]).Distinct().Count());
        Assert.All(samples, entry =>
        {
            Assert.Equal("background", entry.State["Source"]);
            Assert.Null(entry.State["RequestId"]);
            Assert.NotEqual(ambient.TraceId.ToString(), entry.State["TraceId"]);
        });
    }

    [Fact]
    public async Task LivenessAndStatsDoNotProduceReadinessAccessLogs()
    {
        using var logs = new CapturedLogs();
        using var factory = new ProbeFactory().WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddSingleton<ILoggerProvider>(logs)));
        using var client = factory.CreateClient();
        await client.GetAsync("/health/liveness");
        await client.GetAsync("/diagnostics/stats");
        Assert.Empty(logs.ReadinessEntries());
    }

    [Fact]
    public async Task CanceledRequestsKeepTraceAndDoNotClaimAnHttp499Response()
    {
        using var logs = new CapturedLogs();
        using var loggerFactory = LoggerFactory.Create(builder => builder.AddProvider(logs));
        using var cancellation = new CancellationTokenSource();
        var context = new DefaultHttpContext();
        context.Request.Path = "/health/readiness";
        context.RequestAborted = cancellation.Token;
        var middleware = new ReadinessRequestLogging(_ =>
        {
            cancellation.Cancel();
            return Task.FromCanceled(cancellation.Token);
        }, loggerFactory.CreateLogger<ReadinessRequestLogging>());
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => middleware.InvokeAsync(context));
        var entries = logs.ReadinessEntries();
        var canceled = Assert.Single(entries, entry => entry.Event.Name == "ReadinessRequestCanceled");
        Assert.Equal(context.Response.Headers["X-Trace-Id"].ToString(), canceled.State["TraceId"]);
        Assert.False(canceled.State.ContainsKey("HttpStatusCode"));
        Assert.DoesNotContain(entries, entry => entry.Event.Name == "ReadinessRequestCompleted");
    }

    private static Exception Failure()
    {
        try
        {
            throw new IOException("Password=DO-NOT-LOG-SECRET", new SocketException((int)SocketError.ConnectionRefused));
        }
        catch (IOException exception)
        {
            return exception;
        }
    }

    private sealed record CapturedEntry(EventId Event, LogLevel Level, string Message,
        IReadOnlyDictionary<string, object?> State, Exception? Exception);

    private sealed class CapturedLogs : ILoggerProvider
    {
        private readonly ConcurrentQueue<(string Category, CapturedEntry Entry)> _entries = new();

        public CapturedEntry[] ReadinessEntries() => _entries
            .Where(item => item.Category.StartsWith("Els.ReadinessProbe.", StringComparison.Ordinal))
            .Select(item => item.Entry).ToArray();

        public ILogger CreateLogger(string categoryName) => new CaptureLogger(categoryName, _entries);
        public void Dispose() { }

        private sealed class CaptureLogger(string category,
            ConcurrentQueue<(string Category, CapturedEntry Entry)> entries) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
            public bool IsEnabled(LogLevel logLevel) => true;
            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
                Func<TState, Exception?, string> formatter)
            {
                var fields = (state as IEnumerable<KeyValuePair<string, object?>>)?.ToDictionary(pair => pair.Key, pair => pair.Value)
                    ?? new Dictionary<string, object?>();
                entries.Enqueue((category, new CapturedEntry(eventId, logLevel, formatter(state, exception), fields, exception)));
            }
        }
    }
}
