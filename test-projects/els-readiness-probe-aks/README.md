# Standalone AKS deployment for the ELS readiness probe

Build and deploy the [.NET 10 readiness probe](../els-readiness-probe/README.md)
independently of the FeatBit Helm release. The files define one Deployment and
one ClusterIP Service in the existing `featbit` namespace, using existing PG/Redis
Secrets. No generator or additional runtime configuration file is required.

The Azure and Kubernetes commands below are future deployment instructions.
They have not been run during implementation or local validation.

## 1. Build the image locally

Use Docker with BuildKit and Linux containers. Run from the **repository root**:

```powershell
$RegistryLoginServer = '<actual login server of your existing ACR>'
$Tag = git rev-parse --short HEAD
$Image = "$RegistryLoginServer/els-readiness-probe:$Tag"

docker build --platform linux/amd64 --file test-projects/els-readiness-probe-aks/Dockerfile --tag $Image test-projects/els-readiness-probe
```

Use `linux/arm64` instead if that matches your target nodes. The Dockerfile builds
the existing application directly and runs it as the .NET runtime image's non-root
user. Keep credentials in runtime configuration, outside the image.

The build context is just the application directory; FeatBit values and deployment
YAML are outside it. `Dockerfile.dockerignore` excludes local settings, tests, and bin/obj.
Keep the tracked `appsettings.json` credentials empty and `NuGet.Config` public.
See Docker's [Dockerfile-specific ignore-file rules](https://docs.docker.com/build/concepts/context/#filename-and-location).

## 2. Edit the Deployment YAML

From `test-projects/els-readiness-probe-aks`:

```powershell
Copy-Item deployment.yaml deployment.local.yaml
```

Edit this Git-ignored YAML directly:

- Set `image` to the exact `$Image` built above.
- Set `Postgres__ConnectionString` and `Redis__ConnectionString` to the effective
  ELS connection strings from your existing
  `charts/featbit/examples/aks/featbit-aks-values.local.yaml` and Chart defaults.
  Preserve database, user, TLS, pooling, timeouts, and extra parameters. Check
  `els.env` for explicit overrides; copy any explicit Redis connect/sync timeout
  overrides into this Deployment's `env` list if present.
- Confirm the password references below match your current ELS configuration.
  Change only this test Deployment if the existing Secret names or keys differ.

| Environment variable | Existing Secret | Key |
| --- | --- | --- |
| `Postgres__Password` | `featbit-pg-wu3-secret` | `password` |
| `Redis__Password` | `featbit-redis-wu3-secret` | `password` |

These Secret references match the previously inspected local values. The connection
strings and image in `deployment.yaml` are placeholders and must be replaced.
For external PostgreSQL, retain the Chart's
`Host=<hosts>;Port=<ports>;Username=<username>;Database=<database>` plus
`externalPostgresql.extraParams`. For Redis, preserve the complete ELS connection
string, including database, TLS, user, and cluster/sentinel options where applicable.

Passwords stay in `valueFrom.secretKeyRef`; do not paste their contents into YAML.
If ELS already stores an entire connection string in a Secret, use the same
`valueFrom.secretKeyRef` for that connection variable instead of `value`.

The Secrets and namespace must already exist. The existing ELS Key Vault CSI setup
continues managing its current Secret lifecycle. This test workload does not create
Secrets or copy CSI mounts. Environment-based credential changes require restarting
the test Pod to take effect.

Leave the FeatBit Chart, values, Secrets, and existing workloads unchanged.

## 3. Push to the existing ACR later

After signing in to the intended Azure account, use an explicit subscription:

```powershell
$Subscription = '<target subscription ID>'
$AcrName = '<existing ACR name>'

az acr login --subscription $Subscription --name $AcrName
docker push $Image
```

Verify `$RegistryLoginServer` belongs to that registry. The AKS kubelet must already
have image-pull access; these instructions do not change identities or role
assignments. See the [ACR Docker CLI guide](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli).

## 4. Deploy later into the existing namespace

Review `deployment.local.yaml` and `service.yaml` first. Then, from this directory,
use the intended context explicitly:

```powershell
$Context = '<explicit AKS context>'

# Inspect metadata only; adjust the Secret names if your configuration differs.
kubectl --context $Context --namespace featbit get secret featbit-pg-wu3-secret featbit-redis-wu3-secret

# First deployment only: create fails if either resource already exists.
kubectl --context $Context --namespace featbit create -f deployment.local.yaml -f service.yaml
kubectl --context $Context --namespace featbit rollout status deployment/els-readiness-probe
```

The dedicated `els-readiness-probe` labels keep the Pod separate from existing
FeatBit Service selectors. No Ingress or public endpoint is created. Check applicable
network policies and dependency reachability separately before deployment.

Start with **one replica**, requests of **100m CPU / 128Mi**, and limits of
**500m CPU / 512Mi**, then adjust from observed usage. `Recreate` avoids overlapping
samplers during an update. The probe adds its own PostgreSQL pool, Redis multiplexer,
and dependency traffic; statistics reset when its process restarts.

## Sampling and observation

The supplied YAML enables background dependency sampling, waiting 30 seconds
after each completed check. Kubernetes probes explicitly call `/health/liveness`,
so PG/Redis failures do not restart the service or block access to statistics.
An HTTP call to `/health/readiness` adds another recorded dependency check.

If you want kubelet to call `/health/readiness` instead, edit only this test
Deployment: set `Probe__Enabled` to `"false"`, change `readinessProbe.httpGet.path`
to `/health/readiness`, set its `periodSeconds` to `30`, and allow an HTTP timeout
such as `60` seconds after checking the actual driver timeouts. Keep startup and
liveness on `/health/liveness`. This avoids running both samplers. Dependency
failures can then mark the Pod NotReady; requests canceled without a complete
report are excluded from the application's counters.

After a future deployment, inspect only this workload:

```powershell
kubectl --context $Context --namespace featbit logs deployment/els-readiness-probe --follow
# In another terminal; targets a Pod even if it is NotReady.
kubectl --context $Context --namespace featbit port-forward deployment/els-readiness-probe 5080:5080
Invoke-RestMethod http://localhost:5080/diagnostics/stats | ConvertTo-Json -Depth 10
```

Endpoints have no authentication; keep access through ClusterIP/local port-forward.
See the [application README](../els-readiness-probe/README.md) for counter semantics
and the limits of reproducing production failures with readiness checks.

Readiness events are single-line JSON on container stdout. Use their shared
`TraceId` to correlate requests and dependency results through your existing
container log collection, as with ELS. This project does not configure monitoring
or add an Azure ingestion client.

## Remove the test workload later

Delete only the resources created for this test:

```powershell
kubectl --context $Context --namespace featbit delete deployment/els-readiness-probe service/els-readiness-probe
```

## Local validation

From `test-projects/els-readiness-probe`:

```powershell
dotnet test Els.ReadinessProbe.slnx --configuration Release
```

Application tests use simulated checks and closed loopback ports. They do not access
the configured PG/Redis servers or AKS. The Docker build in step 1 validates image
packaging when a local engine is available. Linux runtime behavior, ACR pulls, live
Secret availability, network/TLS reachability, and real failure rates require later
validation in an explicitly selected environment.
