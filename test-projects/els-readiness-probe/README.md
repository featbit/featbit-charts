# ELS readiness probe

A standalone .NET 10 ASP.NET Core test service that follows FeatBit ELS
PostgreSQL/Redis readiness-check behavior and records failure rates and latency.
It executes dependency checks directly rather than calling a running ELS over HTTP.

The application does not require the full FeatBit source tree, Azure SDK,
OpenTelemetry, or a Collector. Independent Docker and Kubernetes files are in
[els-readiness-probe-aks](../els-readiness-probe-aks/README.md).

## Relationship to ELS

Based on [featbit/featbit](https://github.com/featbit/featbit) ELS source at commit
[`37b4b81371b1d228a29970633201a6969f2a6264`](https://github.com/featbit/featbit/tree/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server):

- [HealthCheckBuilderExtensions.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/HealthCheckBuilderExtensions.cs): PostgreSQL/Redis check registration.
- [MiddlewaresRegister.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Api/Setup/MiddlewaresRegister.cs): checks tagged `Readiness`, using default health-status/HTTP mappings.
- [RedisClient.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/Caches/Redis/RedisClient.cs): shared lazy `ConnectionMultiplexer`, explicit Redis parameters, and connection recovery/timeout defaults.
- [Infrastructure.csproj](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/Infrastructure.csproj): dependency versions.

| Area | Probe behavior |
| --- | --- |
| Runtime | .NET 10, matching the reported ELS major version; .NET 11 is not required |
| PostgreSQL | `AspNetCore.HealthChecks.NpgSql 9.0.0` and `Npgsql 10.0.2`; singleton pooled `NpgsqlDataSource`, opening a connection and running the package's default `SELECT 1` check |
| PostgreSQL timeout | No extra health-check timeout, matching ELS; connection/command timeouts come from the connection string |
| Redis | `AspNetCore.HealthChecks.Redis 9.0.0` and `StackExchange.Redis 2.13.1`; shared lazy multiplexer, using the package's PING/cluster health checks |
| Redis check timeout | Registered as five seconds, matching ELS; underlying operations still depend on driver timeouts and cancellation support |
| Redis defaults | Add `abortConnect=false`, `connectTimeout=1500`, and `syncTimeout=1500` when unspecified; support `Redis__ConnectTimeoutMs` / `Redis__SyncTimeoutMs` |

These versions were checked against source, not every dependency inside the
production image. The project extracts only PostgreSQL/Redis readiness checks.
It does not load ELS stores, message consumers, business requests, MongoDB, Kafka,
or control-plane checks.

## Run locally

Install the .NET 10 SDK. `global.json` permits installed stable .NET 10 SDK feature
bands. From this directory:

```powershell
dotnet restore Els.ReadinessProbe.slnx --configfile NuGet.Config
dotnet build Els.ReadinessProbe.slnx --no-restore
dotnet test Els.ReadinessProbe.slnx --no-restore
```

Connection configuration uses the same keys as ELS, with separate password
overrides. Explicitly configure the intended test targets before starting:

```powershell
$env:Postgres__ConnectionString = 'Host=<postgres-host>;Port=5432;Database=featbit;Username=<user>;Timeout=15;SSL Mode=VerifyFull'
$env:Postgres__Password = '<password>'
$env:Redis__ConnectionString = '<redis-host>:6380,ssl=true'
$env:Redis__Password = '<password>'

dotnet run --project src/Els.ReadinessProbe --no-launch-profile
```

These addresses and credentials are placeholders. Missing connection strings fail
startup so an unconfigured service cannot report healthy dependencies. Keep real
connection strings out of tracked files.

Alternatively, copy `src/Els.ReadinessProbe/appsettings.Local.example.json` to
`appsettings.Local.json` in the same directory and edit it. That local file is
Git-ignored; environment variables and command-line configuration take precedence.
Pooling, TLS, GSS, and other connection-string options retain driver behavior;
the probe does not change them to target a suspected root cause.

The default listener is `http://localhost:5080`:

```powershell
Invoke-WebRequest http://localhost:5080/health/liveness
Invoke-WebRequest http://localhost:5080/health/readiness
Invoke-RestMethod http://localhost:5080/diagnostics/stats | ConvertTo-Json -Depth 10
```

You can also use [requests.http](requests.http). Endpoints have no authentication;
define the intended access scope before exposing this diagnostic service.

## Endpoints and statistics

| Endpoint | Behavior |
| --- | --- |
| `GET /health/liveness` | Returns `200 Healthy` without PostgreSQL/Redis access or recording a sample |
| `GET /health/readiness` | Runs tagged PostgreSQL/Redis checks concurrently; default mapping is `200 Healthy` / `200 Degraded` / `503 Unhealthy`; records one sample per complete report |
| `GET /diagnostics/stats` | Returns a snapshot without dependency I/O: counts, per-dependency error rates, mean/max latency, latest results, and bounded recent failures |

Statistics count **health-check invocations**, not TCP packets, driver retries,
or individual Redis commands:

- `completedRuns`: complete readiness reports recorded in this process.
- `readinessFailureRate`: unhealthy reports divided by complete reports, from 0 to 1; corresponds to the default HTTP 503 ratio.
- `checks.npgsql` / `checks.redis`: per-dependency completed attempts, healthy/degraded/unhealthy counts, latency, and latest results.
- Per-dependency `errorRate`: `(degraded + unhealthy) / completed attempts`, from 0 to 1.
- `runsBySource`: separates HTTP checks and background sampling. Both count toward totals if both run.
- `recentFailures`: non-healthy reports, newest first, retaining at most 100 by default.

Counters are thread-safe, process-local, and reset on restart. Multiple instances
are not aggregated. Canceled checks without a complete report do not enter these
denominators; these rates are not production HTTP 499/500 rates.

## Readiness logs and trace correlation

Every `/health/readiness` request logs its start and completion, including HTTP
status and elapsed milliseconds. Every complete sample logs the overall result
and separate PostgreSQL/Redis results, including healthy checks and their durations.
Requests canceled before completion get a cancellation event instead of a claimed
HTTP 499 response. Liveness and statistics requests do not generate readiness logs.

Readiness events are single-line JSON on stdout with structured fields under
`State`: `TraceId`, `SpanId`, `Source`, and, when available, `RequestId`, `SampleId`,
`Check`, `Status`, and `DurationMs`. UTC timestamps and log severity are also present.
An incoming W3C `traceparent` is preserved; otherwise the request gets a new trace.
Each background sample has its own trace and `Source=background`.

Responses include `X-Trace-Id` and, for complete reports, `X-Probe-Sample-Id`:

```powershell
$response = Invoke-WebRequest http://localhost:5080/health/readiness -SkipHttpErrorCheck
$response.Headers['X-Trace-Id']
$response.Headers['X-Probe-Sample-Id']
```

Recent failures in `/diagnostics/stats` also include `traceId`, `spanId`, and
`requestId`. `SampleId` is process-local; use `TraceId` and Pod identity when
correlating observations across restarts or replicas.

Failures log each captured nested exception separately: exception type, HResult,
transient flag, SQLSTATE, socket/native error codes, and stack frames when available.
At most 16 exceptions are traversed; each stack is capped at 2,048 characters with
`StackTraceTruncated=true` when shortened. The application does not log raw exception
messages, health-check descriptions, connection strings, passwords, request headers,
or query strings. Full exception text is not passed to the logger.

Framework health-check error logging remains suppressed to avoid repeating raw
exceptions. Additional Npgsql connection diagnostics can be enabled temporarily
using `Logging__LogLevel__Npgsql.Connection=Trace` in this test application's `env`.
This uses Microsoft logging levels, not the ELS Serilog `Verbose` setting. Validate
the additional driver output separately. Earlier exceptions swallowed inside the
driver are still not guaranteed to appear in a completed health report.

See the [Azure Monitor queries](../els-readiness-probe-aks/README.md#view-logs-in-azure-monitor)
for finding these events after an explicitly chosen deployment.

## Optional background sampling

Background sampling is disabled by default. With it disabled, only a readiness
request triggers dependency access. To enable continuous observation explicitly:

```powershell
$env:Probe__Enabled = 'true'
$env:Probe__IntervalSeconds = '10'
$env:Probe__RecentFailureLimit = '100'

dotnet run --project src/Els.ReadinessProbe --no-launch-profile
```

The sampler runs once on startup, then waits the configured interval after each
completed check. Scheduled samples do not overlap; external readiness requests
can overlap them. Restart to apply configuration changes. Creating these files
does not start sampling against any real environment.

## Validation and limits

Local tests cover HTTP status mapping, liveness/statistics without dependency I/O,
per-dependency error rates, concurrent counters, bounded history, sensitive-message
exclusion, connection configuration, and optional background sampling.

A real-driver test uses closed loopback ports to exercise separate Npgsql/Redis
failure reports. It does not connect to existing databases or prove successful
requests against real PostgreSQL/Redis services.

No production credentials have been used, production failure rates have not been
measured, and nothing has been deployed to AKS. Windows local tests do not reproduce
Linux/AKS network conditions.

Low-load readiness checks differ from `/evaluate` traffic. PostgreSQL may reuse
pooled physical connections, and Redis reuses its multiplexer; successful checks
do not imply a new DNS/TCP/TLS connection each time. A controlled cold-connection
comparison with `Pooling=false` can be considered separately, keeping its samples
distinct from the default ELS behavior.

The service does not modify business data to generate traffic and does not
guarantee capture of the first exception masked by Npgsql negotiation fallback.
