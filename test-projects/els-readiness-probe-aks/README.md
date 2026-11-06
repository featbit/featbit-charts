# Standalone AKS deployment for the ELS readiness probe

This directory packages the existing [.NET 10 readiness probe](../els-readiness-probe/README.md)
as an independent container, Kubernetes Deployment, and ClusterIP Service.
It is separate from the FeatBit Helm release and does not modify the FeatBit Chart,
existing values, Secrets, SecretProviderClasses, or Deployments.

`prepare.ps1` and `prepare.py` **only read and write local files**. They do not run
`az`, `docker`, `kubectl`, or `helm`. Azure and AKS commands below are instructions
for a future, explicitly chosen deployment; they have not been executed as part
of this implementation.

## Files

- `Dockerfile`: multi-stage .NET 10 Linux build, using the runtime image's non-root user.
- `.dockerignore`: additional protection for the isolated build context.
- `deployment.template.yaml`: one replica, dedicated labels, port 5080, resource limits, and probes.
- `service.yaml`: a dedicated ClusterIP Service, without Ingress or public exposure.
- `prepare.ps1` / `prepare.py`: generate a runtime manifest and a separate minimal build context.
- `tests/`: local preparation tests and a smoke test for a locally published application.

Do not deploy the template directly. Generate and review `deployment.local.yaml` first.

## 1. Prepare files locally

Run from this directory with Python 3.10+ and pip installed:

```powershell
python -m pip install -r requirements.txt

$RegistryLoginServer = '<actual loginServer of an existing ACR>'
$Tag = git rev-parse --short HEAD
$ImageName = "els-readiness-probe:$Tag"
$Image = "$RegistryLoginServer/$ImageName"

$prepared = .\prepare.ps1 -Image $Image | ConvertFrom-Json
$prepared
```

Outputs default to the Git-ignored `.generated/<UTC timestamp>/` directory.
Each run creates a new directory instead of overwriting previous outputs.
Use `-OutputDirectory <new-directory>` to choose a different fresh directory.
The default namespace is `featbit`; override it explicitly with `-Namespace`.

The helper reads and merges these files without changing them or invoking Helm:

1. `charts/featbit/values.yaml` supplies defaults.
2. `charts/featbit/examples/aks/featbit-aks-values.local.yaml` supplies the existing
   ELS connection configuration. Use `-ValuesFile` to select another local file.

Only external PostgreSQL and Redis are supported. The helper reproduces the
Chart's external connection-string rules, preserving PostgreSQL extra parameters,
Redis TLS/database/user settings, and supported ELS environment overrides.
Unsupported configuration stops preparation rather than guessing passwords or
creating Secrets. Recheck the helper's output if those Chart rules change.

The currently inspected local values reference:

| Environment variable | Existing Kubernetes Secret / key |
| --- | --- |
| `Postgres__Password` | `featbit-pg-wu3-secret` / `password` |
| `Redis__Password` | `featbit-redis-wu3-secret` / `password` |

Generated references follow the input values' `existingSecret` and
`existingSecretPasswordKey`; explicit `secretKeyRef` overrides in `els.env`
take precedence. An entire connection string can also reference an existing
Secret. Literal password overrides and connection strings with embedded
credentials or environment-variable expansion are rejected.

Only the two connection strings, two password references, and explicitly supplied
Redis connect/sync timeouts are copied. Other ELS environment settings, Pod labels,
CSI mounts, and unrelated FeatBit configuration are not copied.

The Secrets must already exist in the target namespace. The new Pod only consumes
them: it does not redefine them or read/print their data during preparation.
The existing ELS Key Vault CSI configuration remains responsible for its current
Secret synchronization and lifecycle. Passwords injected as environment variables
are read at process startup; rotation does not automatically refresh a running process.

Preparation produces separate runtime and build artifacts:

```text
.generated/<timestamp>/
|-- deployment.local.yaml    # Runtime connection settings and Secret references
`-- build-context/          # Upload ONLY this directory to ACR
    |-- Dockerfile
    |-- .dockerignore
    |-- global.json
    |-- NuGet.Config
    `-- src/Els.ReadinessProbe/...
```

Runtime connection information is outside the build context. The helper copies
an allowlist of source files, the csproj, empty public application defaults, and
public build configuration. It excludes `appsettings.Local*`, `.env`, tests,
bin/obj, and the rest of the repository. Preparation rejects dependency credentials
in the source `appsettings.json` and private/authenticated NuGet configuration.
The staged NuGet configuration is normalized to the public nuget.org feed.

Do not upload the repository root or the parent `.generated/<timestamp>/`
directory as the ACR build context.

## 2. Build and push later, manually

**This step operates on ACR and pushes an image. It is not local preparation or validation.**
Use an existing registry and verify the subscription and actual registry login server:

```powershell
$Subscription = '<target subscription ID>'
$AcrName = '<existing ACR name>'

# Verify in Azure that the registry/loginServer matches $Image before building.
az acr build --subscription $Subscription --registry $AcrName `
  --image $ImageName --file Dockerfile --platform linux/amd64 $prepared.buildContext
```

ACR Tasks uploads the specified context, builds the image, and pushes it; see the
[official guide](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-quick-task).
ARM64 nodes require the corresponding build platform and separate validation.
AKS image-pull permissions must also be checked separately. This directory does
not change kubelet identities, ACR roles, or existing imagePullSecrets.

Optional build command for a Docker engine running on your own machine:

```powershell
docker build --tag els-readiness-probe:local --file (Join-Path $prepared.buildContext 'Dockerfile') $prepared.buildContext
```

## 3. Deploy later, manually, into the existing namespace

**The following commands access or modify the selected AKS cluster. They are
future operator instructions and were not executed during implementation.**

Review the generated manifest first. Verify the actual context, namespace,
Secret names, and image-pull permissions. Local values are not a live cluster
snapshot; their agreement with the deployed ELS configuration remains unverified.

```powershell
$Context = '<explicit AKS context>'
$Namespace = $prepared.namespace

# Inspect metadata only; do not print Secret data.
kubectl --context $Context --namespace $Namespace get namespace $Namespace
kubectl --context $Context --namespace $Namespace get secret featbit-pg-wu3-secret featbit-redis-wu3-secret
kubectl --context $Context --namespace $Namespace get deployment/els-readiness-probe service/els-readiness-probe

# Confirm the two test resources do not exist before first creation.
# create fails on a name collision instead of updating that existing resource.
kubectl --context $Context --namespace $Namespace create -f $prepared.manifest
kubectl --context $Context --namespace $Namespace rollout status deployment/els-readiness-probe
```

Adjust the metadata checks if your input values use different Secret names.
Do not create or overwrite shared Secrets. No FeatBit Helm operation or ELS
configuration/restart is required. The namespace must already exist.

Both `app.kubernetes.io/name` and `app.kubernetes.io/instance` are dedicated to
`els-readiness-probe`, so the new Pod does not match the FeatBit Service selectors.
Sharing a namespace does not guarantee identical network permissions. Review
NetworkPolicy or similar restrictions separately; do not copy ELS traffic-selector
labels to bypass them.

Initial requests are `100m CPU / 128Mi`, with limits of `500m CPU / 512Mi`.
These are starting values, not a capacity guarantee. Start with one replica;
the application has its own PostgreSQL pool and Redis multiplexer and adds a
small amount of dependency traffic. The `Recreate` update strategy avoids two
samplers running concurrently during an update. Updates and restarts reset the
in-process statistics.

## 4. Sampling and Kubernetes probes

The default **background mode** sets `Probe__Enabled=true` and waits 30 seconds
after each completed dependency check before the next sample. All Kubernetes
startup/liveness/readiness probes call `/health/liveness`: Pod readiness here means
the diagnostic service can serve statistics. Dependency health is measured by the
background sampler instead of causing liveness restarts or blocking statistics.
Manually calling `/health/readiness` still adds an HTTP-source sample.

To test kubelet HTTP readiness behavior, prepare a separate **kubelet mode** manifest:

```powershell
$prepared = .\prepare.ps1 -Image $Image -SamplingMode kubelet -IntervalSeconds 30 | ConvertFrom-Json
```

This disables background sampling. Only `readinessProbe` calls `/health/readiness`;
startup/liveness continue checking the process itself. The initial HTTP timeout is
60 seconds: verify it against the actual PostgreSQL connection/command timeouts
before deployment. It is not a driver timeout. Canceled requests without complete
reports are excluded from the current counters, and kubelet retry scheduling is
not a strict fixed sampling interval. Do not enable both sampling methods.
See the [Kubernetes probe documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).

Inspect only the test service's logs and statistics:

```powershell
kubectl --context $Context --namespace $Namespace logs deployment/els-readiness-probe --follow
# Run in another terminal. Target the Deployment's Pod even if it is NotReady.
kubectl --context $Context --namespace $Namespace port-forward deployment/els-readiness-probe 5080:5080
Invoke-RestMethod http://localhost:5080/diagnostics/stats | ConvertTo-Json -Depth 10
```

The endpoints do not have authentication. Keep the ClusterIP/local port-forward
access pattern rather than adding public exposure. Statistics are not persisted
across Pods or restarts; retain the observation logs when needed.

## 5. Remove the test resources later, manually

After confirming these are the two resources created for this test, delete only them:

```powershell
kubectl --context $Context --namespace $Namespace delete deployment/els-readiness-probe service/els-readiness-probe
```

Do not delete the namespace, shared Secrets, SecretProviderClasses, other
Deployments, or the FeatBit Helm release.

## Local validation

```powershell
python -m unittest discover -s tests -v

# Existing application regression tests; real-driver failure tests use loopback ports only.
Push-Location ../els-readiness-probe
dotnet test Els.ReadinessProbe.slnx --configuration Release
Pop-Location
```

Checks cover resource/selector isolation, both probe modes, configuration
inheritance, Secret references, excluded sensitive files, separate runtime/build
artifacts, and unchanged input files. Local validation does not call kubectl,
including client-side dry runs that might perform API discovery.

If a Docker engine is unavailable, the generated context can still be checked
with `dotnet restore`, `dotnet publish`, and a loopback smoke test:

```powershell
# Point to an already published DLL. This starts and stops only a local child process.
python tests/smoke_published.py --dll '<local-publish-directory>/Els.ReadinessProbe.dll'
```

That validates the packaged source and application behavior, not a built/running
Linux Docker image. Linux non-root/read-only filesystem behavior, ACR pull
permissions, live Secret availability, network/TLS reachability, and real
PostgreSQL/Redis error rates require later validation in an explicitly selected environment.
