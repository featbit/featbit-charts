using Els.ReadinessProbe;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true);
// Environment variables and command-line values take precedence over the local file.
builder.Configuration.AddEnvironmentVariables();
builder.Configuration.AddCommandLine(args);

builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.UseUtcTimestamp = true;
    options.TimestampFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";
});

builder.Services.AddOptions<ProbeOptions>()
    .BindConfiguration("Probe")
    .ValidateDataAnnotations()
    .Validate<IConfiguration>((_, configuration) => ProbeConnections.IsValid(configuration),
        "Set valid Postgres__ConnectionString and Redis__ConnectionString before starting the probe.")
    .ValidateOnStart();
builder.Services.AddElsReadiness();
builder.Services.AddSingleton<ProbeRecorder>();
builder.Services.AddHostedService<ProbeSampler>();

var app = builder.Build();

app.MapHealthChecks("/health/liveness", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/readiness", new HealthCheckOptions
{
    Predicate = Readiness.IsReadiness,
    ResponseWriter = async (context, report) =>
    {
        context.RequestServices.GetRequiredService<ProbeRecorder>().Record(report, "http");
        context.Response.ContentType = "text/plain; charset=utf-8";
        await context.Response.WriteAsync(report.Status.ToString(), context.RequestAborted);
    }
});
// A snapshot only: viewing statistics does not issue database/cache requests.
app.MapGet("/diagnostics/stats", (ProbeRecorder recorder) => recorder.Snapshot());
app.MapGet("/", () => Results.Ok(new
{
    service = "els-readiness-probe",
    readiness = "/health/readiness",
    liveness = "/health/liveness",
    statistics = "/diagnostics/stats"
}));

app.Run();

public partial class Program;
