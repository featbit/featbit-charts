using System.Diagnostics;

namespace Els.ReadinessProbe;

public sealed class ReadinessRequestLogging(RequestDelegate next, ILogger<ReadinessRequestLogging> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (!string.Equals(context.Request.Path.Value?.TrimEnd('/'), "/health/readiness", StringComparison.OrdinalIgnoreCase))
        {
            await next(context);
            return;
        }

        // Reuse ASP.NET's server activity when present, including any upstream traceparent.
        using var fallback = Activity.Current is { IdFormat: ActivityIdFormat.W3C } ? null : StartActivity(context);
        var activity = Activity.Current!;
        var traceId = activity.TraceId.ToString();
        var spanId = activity.SpanId.ToString();
        var requestId = context.TraceIdentifier;
        context.Response.Headers["X-Trace-Id"] = traceId;
        using var scope = logger.BeginScope(new Dictionary<string, object?>
        {
            ["Source"] = "http",
            ["RequestId"] = requestId
        });
        var started = Stopwatch.GetTimestamp();
        // Only the route is logged: query strings and request headers can contain credentials.
        logger.LogInformation(new EventId(1000, "ReadinessRequestStarted"),
            "Readiness request started TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} Source={Source} Method={Method} Path={Path}",
            traceId, spanId, requestId, "http", context.Request.Method, context.Request.Path.Value);
        try
        {
            await next(context);
            if (context.RequestAborted.IsCancellationRequested)
            {
                LogCanceled();
                return;
            }
            long? sampleId = long.TryParse(context.Response.Headers["X-Probe-Sample-Id"], out var id) ? id : null;
            logger.Log(context.Response.StatusCode >= 500 ? LogLevel.Warning : LogLevel.Information,
                new EventId(1003, "ReadinessRequestCompleted"),
                "Readiness request completed TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} Source={Source} SampleId={SampleId} HttpStatusCode={HttpStatusCode} DurationMs={DurationMs}",
                traceId, spanId, requestId, "http", sampleId, context.Response.StatusCode,
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            LogCanceled();
            throw;
        }
        catch (Exception exception)
        {
            var (stackTrace, truncated) = ErrorDetails.GetStackTrace(exception);
            logger.LogError(new EventId(1006, "ReadinessRequestFailed"),
                "Readiness request failed TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} Source={Source} DurationMs={DurationMs} ExceptionType={ExceptionType} HResult={HResult} StackTrace={StackTrace} StackTraceTruncated={StackTraceTruncated}",
                traceId, spanId, requestId, "http", Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                exception.GetType().FullName, exception.HResult, stackTrace, truncated);
            throw;
        }

        void LogCanceled() => logger.LogWarning(new EventId(1005, "ReadinessRequestCanceled"),
            "Readiness request canceled TraceId={TraceId} SpanId={SpanId} RequestId={RequestId} Source={Source} DurationMs={DurationMs}",
            traceId, spanId, requestId, "http", Stopwatch.GetElapsedTime(started).TotalMilliseconds);
    }

    private static Activity StartActivity(HttpContext context)
    {
        var activity = new Activity("Readiness.Http").SetIdFormat(ActivityIdFormat.W3C);
        if (ActivityContext.TryParse(context.Request.Headers["traceparent"], context.Request.Headers["tracestate"], out var parent))
        {
            activity.SetParentId(parent.TraceId, parent.SpanId, parent.TraceFlags);
        }
        return activity.Start();
    }
}
