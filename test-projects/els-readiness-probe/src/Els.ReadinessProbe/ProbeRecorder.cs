using System.Diagnostics;
using System.Net.Sockets;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Els.ReadinessProbe;

public sealed class ProbeRecorder(IOptions<ProbeOptions> options, ILogger<ProbeRecorder> logger)
{
    private readonly object _gate = new();
    private readonly DateTimeOffset _startedAtUtc = DateTimeOffset.UtcNow;
    private readonly Dictionary<string, Totals> _checks = new()
    {
        [Readiness.PostgresCheck] = new(),
        [Readiness.RedisCheck] = new()
    };
    private readonly Dictionary<string, long> _runsBySource = new();
    private readonly Queue<ProbeRun> _recentFailures = new();
    private long _completedRuns;
    private long _unhealthyRuns;

    public ProbeRun Record(HealthReport report, string source, string? requestId = null)
    {
        using var fallback = Activity.Current is null
            ? new Activity("Readiness.Sample").SetIdFormat(ActivityIdFormat.W3C).Start()
            : null;
        var traceId = Activity.Current!.TraceId.ToString();
        var spanId = Activity.Current.SpanId.ToString();
        var timestamp = DateTimeOffset.UtcNow;
        var checks = report.Entries.ToDictionary(
            pair => pair.Key,
            pair => new CheckSample(pair.Value.Status.ToString(), pair.Value.Duration.TotalMilliseconds,
                ErrorDetails.FromException(pair.Value.Exception)));
        ProbeRun run;
        lock (_gate)
        {
            var id = ++_completedRuns;
            if (report.Status == HealthStatus.Unhealthy)
            {
                _unhealthyRuns++;
            }
            _runsBySource[source] = _runsBySource.GetValueOrDefault(source) + 1;
            foreach (var (name, entry) in report.Entries)
            {
                if (!_checks.TryGetValue(name, out var totals))
                {
                    totals = _checks[name] = new Totals();
                }
                totals.Attempts++;
                if (entry.Status == HealthStatus.Healthy) totals.Healthy++;
                else if (entry.Status == HealthStatus.Degraded) totals.Degraded++;
                else totals.Unhealthy++;
                totals.TotalDurationMs += entry.Duration.TotalMilliseconds;
                totals.MaxDurationMs = Math.Max(totals.MaxDurationMs, entry.Duration.TotalMilliseconds);
                totals.LastCheckedAtUtc = timestamp;
                totals.LastResult = checks[name];
            }
            run = new ProbeRun(id, timestamp, source, report.Status.ToString(),
                report.TotalDuration.TotalMilliseconds, checks, traceId, spanId, requestId);
            if (report.Status != HealthStatus.Healthy)
            {
                _recentFailures.Enqueue(run);
                while (_recentFailures.Count > options.Value.RecentFailureLimit)
                {
                    _recentFailures.Dequeue();
                }
            }
        }

        logger.Log(report.Status == HealthStatus.Healthy ? LogLevel.Information : LogLevel.Warning,
            new EventId(1001, "ReadinessSampleCompleted"),
            "Readiness sample completed TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} SampleId={SampleId} Source={Source} Status={Status} DurationMs={DurationMs}",
            traceId, spanId, requestId, run.Id, source, run.Status, run.DurationMs);
        // Healthy checks are also logged so both dependencies appear in every completed sample.
        foreach (var (name, result) in checks)
        {
            logger.Log(result.Status == nameof(HealthStatus.Healthy) ? LogLevel.Information : LogLevel.Warning,
                new EventId(1002, "ReadinessDependencyCompleted"),
                "Readiness dependency completed TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} SampleId={SampleId} Source={Source} Check={Check} Status={Status} DurationMs={DurationMs} ExceptionTypes={ExceptionTypes} SqlState={SqlState} SocketError={SocketError}",
                traceId, spanId, requestId, run.Id, source, name, result.Status, result.DurationMs,
                string.Join(" -> ", result.Error?.ExceptionTypes ?? []), result.Error?.SqlState, result.Error?.SocketError);
            var index = 0;
            foreach (var exception in ErrorDetails.ExceptionChain(report.Entries[name].Exception))
            {
                var (stackTrace, truncated) = ErrorDetails.GetStackTrace(exception);
                // Log each exception separately, without ToString()/Message or the raw ILogger exception argument.
                logger.LogWarning(new EventId(1004, "ReadinessDependencyException"),
                    "Readiness dependency exception TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} SampleId={SampleId} Source={Source} Check={Check} ExceptionIndex={ExceptionIndex} ExceptionType={ExceptionType} HResult={HResult} IsTransient={IsTransient} SqlState={SqlState} SocketError={SocketError} NativeErrorCode={NativeErrorCode} StackTrace={StackTrace} StackTraceTruncated={StackTraceTruncated}",
                    traceId, spanId, requestId, run.Id, source, name, index++, exception.GetType().FullName,
                    exception.HResult, (exception as NpgsqlException)?.IsTransient,
                    (exception as PostgresException)?.SqlState, (exception as SocketException)?.SocketErrorCode.ToString(),
                    (exception as SocketException)?.NativeErrorCode, stackTrace, truncated);
            }
        }
        return run;
    }

    public StatisticsSnapshot Snapshot()
    {
        lock (_gate)
        {
            return new StatisticsSnapshot(_startedAtUtc, DateTimeOffset.UtcNow,
                _completedRuns, _unhealthyRuns, Rate(_unhealthyRuns, _completedRuns),
                new Dictionary<string, long>(_runsBySource),
                _checks.ToDictionary(pair => pair.Key, pair => pair.Value.Snapshot()),
                _recentFailures.Reverse().ToArray());
        }
    }

    private static double Rate(long failures, long attempts) => attempts == 0 ? 0 : (double)failures / attempts;

    private sealed class Totals
    {
        public long Attempts;
        public long Healthy;
        public long Degraded;
        public long Unhealthy;
        public double TotalDurationMs;
        public double MaxDurationMs;
        public DateTimeOffset? LastCheckedAtUtc;
        public CheckSample? LastResult;

        public CheckStatistics Snapshot() => new(Attempts, Healthy, Degraded, Unhealthy,
            Rate(Degraded + Unhealthy, Attempts), Attempts == 0 ? 0 : TotalDurationMs / Attempts,
            MaxDurationMs, LastCheckedAtUtc, LastResult);
    }
}

public sealed record StatisticsSnapshot(DateTimeOffset StartedAtUtc, DateTimeOffset CapturedAtUtc,
    long CompletedRuns, long UnhealthyRuns, double ReadinessFailureRate,
    IReadOnlyDictionary<string, long> RunsBySource,
    IReadOnlyDictionary<string, CheckStatistics> Checks, IReadOnlyList<ProbeRun> RecentFailures);

public sealed record CheckStatistics(long Attempts, long Healthy, long Degraded, long Unhealthy,
    double ErrorRate, double MeanDurationMs, double MaxDurationMs,
    DateTimeOffset? LastCheckedAtUtc, CheckSample? LastResult);

public sealed record ProbeRun(long Id, DateTimeOffset TimestampUtc, string Source,
    string Status, double DurationMs, IReadOnlyDictionary<string, CheckSample> Checks,
    string TraceId, string SpanId, string? RequestId);

public sealed record CheckSample(string Status, double DurationMs, ErrorDetails? Error);

// Deliberately omit exception messages, descriptions, SQL and connection strings.
public sealed record ErrorDetails(IReadOnlyList<string> ExceptionTypes, string? SqlState, string? SocketError)
{
    public static ErrorDetails? FromException(Exception? exception)
    {
        if (exception is null) return null;
        var types = new List<string>();
        string? sqlState = null;
        string? socketError = null;
        foreach (var current in ExceptionChain(exception))
        {
            types.Add(current.GetType().FullName ?? current.GetType().Name);
            if (current is PostgresException postgres) sqlState ??= postgres.SqlState;
            if (current is SocketException socket) socketError ??= socket.SocketErrorCode.ToString();
        }
        return new ErrorDetails(types, sqlState, socketError);
    }

    internal static (string? Text, bool Truncated) GetStackTrace(Exception exception)
    {
        const int limit = 2048;
        var text = exception.StackTrace;
        return text is { Length: > limit } ? (text[..limit], true) : (text, false);
    }

    internal static IEnumerable<Exception> ExceptionChain(Exception? exception)
    {
        if (exception is null) yield break;
        var pending = new Queue<Exception>();
        var visited = new HashSet<Exception>(ReferenceEqualityComparer.Instance);
        pending.Enqueue(exception);
        while (pending.TryDequeue(out var current) && visited.Count < 16)
        {
            if (!visited.Add(current)) continue;
            yield return current;
            if (current is AggregateException aggregate)
            {
                foreach (var inner in aggregate.InnerExceptions) pending.Enqueue(inner);
            }
            else if (current.InnerException is { } inner)
            {
                pending.Enqueue(inner);
            }
        }
    }
}
