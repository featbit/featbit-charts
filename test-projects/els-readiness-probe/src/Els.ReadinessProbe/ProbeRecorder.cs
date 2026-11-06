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

    public void Record(HealthReport report, string source)
    {
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
                report.TotalDuration.TotalMilliseconds, checks);
            if (report.Status != HealthStatus.Healthy)
            {
                _recentFailures.Enqueue(run);
                while (_recentFailures.Count > options.Value.RecentFailureLimit)
                {
                    _recentFailures.Dequeue();
                }
            }
        }

        logger.LogInformation("Readiness sample {SampleId} source={Source} status={Status} durationMs={DurationMs}",
            run.Id, source, run.Status, run.DurationMs);
        foreach (var (name, result) in checks.Where(pair => pair.Value.Status != nameof(HealthStatus.Healthy)))
        {
            logger.LogWarning(
                "Dependency failure sample={SampleId} check={Check} status={Status} durationMs={DurationMs} exceptionTypes={ExceptionTypes} sqlState={SqlState} socketError={SocketError}",
                run.Id, name, result.Status, result.DurationMs,
                string.Join(" -> ", result.Error?.ExceptionTypes ?? []), result.Error?.SqlState, result.Error?.SocketError);
        }
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
    string Status, double DurationMs, IReadOnlyDictionary<string, CheckSample> Checks);

public sealed record CheckSample(string Status, double DurationMs, ErrorDetails? Error);

// Deliberately omit exception messages, descriptions, SQL and connection strings.
public sealed record ErrorDetails(IReadOnlyList<string> ExceptionTypes, string? SqlState, string? SocketError)
{
    public static ErrorDetails? FromException(Exception? exception)
    {
        if (exception is null) return null;
        var pending = new Queue<Exception>();
        var visited = new HashSet<Exception>(ReferenceEqualityComparer.Instance);
        var types = new List<string>();
        string? sqlState = null;
        string? socketError = null;
        pending.Enqueue(exception);
        while (pending.TryDequeue(out var current) && visited.Count < 16)
        {
            if (!visited.Add(current)) continue;
            types.Add(current.GetType().FullName ?? current.GetType().Name);
            if (current is PostgresException postgres) sqlState ??= postgres.SqlState;
            if (current is SocketException socket) socketError ??= socket.SocketErrorCode.ToString();
            if (current is AggregateException aggregate)
            {
                foreach (var inner in aggregate.InnerExceptions) pending.Enqueue(inner);
            }
            else if (current.InnerException is { } inner)
            {
                pending.Enqueue(inner);
            }
        }
        return new ErrorDetails(types, sqlState, socketError);
    }
}
