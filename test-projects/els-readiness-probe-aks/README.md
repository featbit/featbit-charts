# Standalone AKS deployment for the ELS readiness probe

Docker and Kubernetes files for the [.NET 10 readiness probe](../els-readiness-probe/README.md).
This is an independent Deployment and ClusterIP Service in the existing `featbit`
namespace. It does not use the FeatBit Helm release to deploy the probe.

Local preparation requires **PowerShell 7+**. Building and testing the application
locally requires the .NET 10 SDK. The preparation script uses built-in PowerShell
commands and only reads and writes local files.

## Prepare locally

From this directory, make a separate, Git-ignored runtime configuration:

```powershell
Copy-Item runtime-config.example.json runtime-config.local.json
```

Edit `runtime-config.local.json` to match the ELS connection settings in
`charts/featbit/examples/aks/featbit-aks-values.local.yaml` and the Chart defaults.
**Leave the existing FeatBit values and Secrets unchanged.** For runtime connection
settings, the script reads only the new JSON file; it does not parse or automatically synchronize Helm values.
Review the configuration again if ELS connection settings change.

| Runtime environment entry | What to copy from the existing ELS configuration |
| --- | --- |
| `Postgres__ConnectionString` | The effective connection string, including host, port, username, database, and all extra connection parameters |
| `Postgres__Password` | The existing PostgreSQL Secret name and password key, as a `valueFrom.secretKeyRef` |
| `Redis__ConnectionString` | The effective connection string, preserving endpoints, database, TLS, user, and cluster/sentinel settings |
| `Redis__Password` | The existing Redis Secret name and password key, as a `valueFrom.secretKeyRef` |

For external PostgreSQL, the Chart builds
`Host=<hosts>;Port=<ports>;Username=<username>;Database=<database>` and appends
`externalPostgresql.extraParams` when present. For standalone external Redis,
it builds `<host>:<port>,defaultDatabase=<db>,abortConnect=false,ssl=<true|false>`
and appends `,user=<user>` when configured. Cluster/sentinel connections follow
the rules in `_redis-config.tpl`; preserve their complete connection strings.
Also check `els.env` for connection overrides and explicit
`Redis__ConnectTimeoutMs` / `Redis__SyncTimeoutMs`; those two optional entries can
be added to the JSON `env` array as string values.

The example references `featbit-pg-wu3-secret/password` and
`featbit-redis-wu3-secret/password`, matching the previously inspected local values.
Confirm these references against your current file. The example connection strings
are placeholders and preparation rejects them until replaced.

Passwords remain in existing Secrets; do not copy their contents into this file.
Entire connection strings may also use `valueFrom.secretKeyRef` if ELS already
uses that arrangement. Literal passwords, embedded connection-string passwords,
environment-variable expansion, duplicate entries, and unrelated ELS environment
variables are rejected. Only the four required entries and the two optional Redis
timeouts are accepted.

Generate the manifest and isolated build context:

```powershell
$RegistryLoginServer = '<actual loginServer of an existing ACR>'
$Tag = git rev-parse --short HEAD
$ImageName = "els-readiness-probe:$Tag"
$Image = "$RegistryLoginServer/$ImageName"

$prepared = ./prepare.ps1 -Image $Image | ConvertFrom-Json
$prepared
```

Use `-ConfigFile` for another local JSON file or `-Namespace` for another existing
namespace. Each run creates a fresh, Git-ignored `.generated/<UTC timestamp>/`
directory; an existing output directory is never overwritten. `-OutputDirectory`
can select a fresh directory beneath `.generated`.

```text
.generated/<timestamp>/
|-- deployment.local.yaml    # Deployment + Service, runtime settings and Secret references
`-- build-context/          # Upload ONLY this directory to ACR
    |-- Dockerfile
    |-- .dockerignore
    |-- global.json
    |-- NuGet.Config
    `-- src/Els.ReadinessProbe/...
```

The script copies an allowlist of application source and public build files.
Runtime configuration, `appsettings.Local*`, `.env`, tests, bin/obj, and the rest
of the repository stay outside the build context. Source `appsettings.json` must
retain empty credentials, and NuGet configuration must use only public nuget.org.

The shared Secrets must already exist in the target namespace. Preparation does
not fetch or print Secret data, create Secrets, or copy the ELS CSI configuration.
Existing ELS Key Vault synchronization remains responsible for its current Secret
lifecycle. Environment-based credentials are read at process startup; rotation
does not automatically refresh a running process.

## Build and push later

The following commands are future operator instructions. They have not been run
as part of this implementation. `az acr build` uploads the context and pushes an
image to the selected existing registry:

```powershell
$Subscription = '<target subscription ID>'
$AcrName = '<existing ACR name>'

# Verify that the registry's actual loginServer matches $Image.
az acr build --subscription $Subscription --registry $AcrName `
  --image $ImageName --file Dockerfile --platform linux/amd64 $prepared.buildContext
```

See the [ACR quick-task guide](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-quick-task).
ARM64 nodes require the corresponding platform and separate validation. Image-pull
permissions must already be configured; this project does not change identities,
ACR roles, or existing imagePullSecrets.

With a local Docker engine, an optional local build is:

```powershell
docker build --tag els-readiness-probe:local --file (Join-Path $prepared.buildContext 'Dockerfile') $prepared.buildContext
```

Upload only `build-context`, never the repository root or its parent generated directory.

## Deploy later

These commands contact or modify the selected cluster. They are documented for a
future deployment and were not executed during implementation or local tests.
Review `deployment.local.yaml` first. Local configuration does not prove that the
live ELS workload has the same settings.

```powershell
$Context = '<explicit AKS context>'
$Namespace = $prepared.namespace

# Check metadata only. Adjust Secret names to match your configuration.
kubectl --context $Context get namespace $Namespace
kubectl --context $Context --namespace $Namespace get secret featbit-pg-wu3-secret featbit-redis-wu3-secret
kubectl --context $Context --namespace $Namespace get deployment/els-readiness-probe service/els-readiness-probe

# Confirm neither test resource exists. create fails on an existing name.
kubectl --context $Context --namespace $Namespace create -f $prepared.manifest
kubectl --context $Context --namespace $Namespace rollout status deployment/els-readiness-probe
```

Both resource selectors use the dedicated name and instance `els-readiness-probe`.
The new Pod does not match FeatBit Service selectors. No FeatBit Chart, values,
Secret, Deployment, or restart is involved. Sharing a namespace does not guarantee
identical network permissions; check applicable policies separately.

Start with **one replica**, requests of **100m CPU / 128Mi**, and limits of
**500m CPU / 512Mi**. These are initial settings to validate under actual load.
The probe has its own PostgreSQL pool and Redis multiplexer and adds dependency
traffic. `Recreate` prevents overlapping replicas during an update. Restarts reset
the in-process statistics.

## Sampling and Kubernetes probes

AKS calls a health endpoint only when a probe is explicitly configured. This
Deployment supplies startup, liveness, and readiness probes.

The default **background** mode enables the application's sampler, waiting 30
seconds after each completed dependency check. All Kubernetes probes call
`/health/liveness`, so dependency failures do not restart the service or prevent
access to statistics. An HTTP call to `/health/readiness` adds another sample.

To test kubelet HTTP readiness behavior instead:

```powershell
$prepared = ./prepare.ps1 -Image $Image -SamplingMode kubelet -IntervalSeconds 30 | ConvertFrom-Json
```

This disables background sampling and makes only `readinessProbe` call
`/health/readiness`; startup and liveness still check the process. The readiness
HTTP timeout starts at 60 seconds. Check it against the actual PostgreSQL
connection/command timeouts before deployment; it does not set driver timeouts.
Canceled requests without a complete report are excluded from counters. Kubelet
scheduling is not a strict fixed sampling interval. Use one sampling mode.
See the [Kubernetes probe documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).

Inspect this test workload later with:

```powershell
kubectl --context $Context --namespace $Namespace logs deployment/els-readiness-probe --follow
# In another terminal; this also works when the Pod is NotReady.
kubectl --context $Context --namespace $Namespace port-forward deployment/els-readiness-probe 5080:5080
Invoke-RestMethod http://localhost:5080/diagnostics/stats | ConvertTo-Json -Depth 10
```

Endpoints have no authentication. Keep access through ClusterIP/local port-forward.
Statistics are not persisted or aggregated across Pods; retain logs if needed.

## Remove the test workload later

After confirming these are the resources created for this test:

```powershell
kubectl --context $Context --namespace $Namespace delete deployment/els-readiness-probe service/els-readiness-probe
```

Leave the namespace, shared Secrets, SecretProviderClasses, and FeatBit release intact.

## Local validation

```powershell
./tests/prepare.tests.ps1

Push-Location ../els-readiness-probe
dotnet test Els.ReadinessProbe.slnx --configuration Release
Pop-Location
```

Preparation tests use synthetic local JSON configuration. They check quoting,
Secret references, sampling modes, input preservation, excluded runtime files,
and refusal to overwrite outputs. Application tests use simulated checks and
closed loopback ports, never the configured remote databases.

The prepared source can also be published locally:

```powershell
dotnet restore (Join-Path $prepared.buildContext 'src/Els.ReadinessProbe/Els.ReadinessProbe.csproj') `
  --configfile (Join-Path $prepared.buildContext 'NuGet.Config')
dotnet publish (Join-Path $prepared.buildContext 'src/Els.ReadinessProbe/Els.ReadinessProbe.csproj') `
  --configuration Release --no-restore --output (Join-Path $prepared.outputDirectory 'publish')
```

Local publication does not validate a running Linux image. Linux non-root/read-only
filesystem behavior, ACR pull permissions, live Secret availability, network/TLS
reachability, and real PostgreSQL/Redis error rates remain for later validation
in an explicitly selected environment.
