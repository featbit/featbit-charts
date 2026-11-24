# Azure Marketplace packaging

`values.yaml` here is an overlay, not a standalone values file. The Marketplace packaging
tool only reads the chart's own `values.yaml`, so the staging step merges this overlay into
a copy of `charts/featbit/values.yaml` before packaging.

## How the chart uses these settings

Azure Marketplace requires every image to be listed under `global.azure.images`, and
rewrites the registry there to its own when publishing. Set `global.azure.images` to specify
the Marketplace image for any of `ui`, `api`, and `els`. Each mapped component uses the
supplied `registry`, `image` (repository path), and `tag`. Components without a mapping
still use the standard image settings, including `global.imageRegistry` when configured.
Without `global.azure.images`, the chart behaves exactly as a normal install.

The built-in BusyBox startup waits are enabled by default. Set `busybox.enabled: false`
to skip these waits. Custom init containers and LoadBalancer auto-discovery retain their
own settings.

## What the overlay sets

The defaults follow our own AKS deployment (`examples/aks/featbit-aks-values.yaml`), adapted
for customer clusters:

- `global.azure.images` for `ui`, `api` and `els`, pointing at the publisher's ACR.
- `busybox.enabled: false` and `autoDiscovery: false`, so no other images are rendered.
- Self-hosted mode. No SaaS billing, SSO or OAuth settings.
- `seccompProfile: RuntimeDefault` and ClusterIP services on port 80 (ingress always targets 80).
- Resources and replicas sized down from our AKS deployment: UI 1 replica; API HPA 3–10;
  Evaluation Server HPA 3–10. At minimum this requests about 3.5 vCPU and 6.5 GiB of memory.
- NGINX ingress with TLS for all three components, a 10 MB upload limit on the API and
  one-hour timeouts for Evaluation Server WebSockets.
- External PostgreSQL and Redis (port 10000, TLS, as with Azure Managed Redis). All bundled
  infrastructure is disabled.

## Secrets

The overlay reads these Secrets from the install namespace:

| Secret | Key | Used for |
| --- | --- | --- |
| `featbit-jwt-key-secret` | `jwt-key` | API `Jwt__Key` |
| `featbit-postgres-secret` | `password` | PostgreSQL password |
| `featbit-redis-secret` | `password` | Redis password (standard tier) |
| `featbit-ui-tls`, `featbit-api-tls`, `featbit-els-tls` | | TLS certificates for the ingresses |

Create them directly with `kubectl create secret`, or sync them from Azure Key Vault:

1. Enable the Azure Key Vault provider for Secrets Store CSI Driver add-on on the AKS cluster.
2. Store the PostgreSQL password, Redis password and JWT key in Key Vault as
   `featbit-postgres-password`, `featbit-redis-password` and `featbit-jwt-key`.
3. Fill in the placeholders in [keyvault-secret-provider.yaml](keyvault-secret-provider.yaml)
   and apply it in the install namespace.
4. Uncomment the `volumeMounts`/`volumes` block for `api` (and `els`) in `values.yaml`.
   The CSI driver only creates the Kubernetes Secrets once a pod mounts the volume.

TLS certificates are not part of this file; create them as `kubernetes.io/tls` Secrets.

## What the portal form / ARM template must supply

Pass these through `configurationSettings` (secrets through `configurationProtectedSettings`).
They replace the `<placeholder>` values:

| Setting | Values keys |
| --- | --- |
| Hostnames | `ui.ingress.host`, `api.ingress.host`, `els.ingress.host` |
| External URLs | `apiExternalUrl`, `evaluationServerExternalUrl` (`https://` + the API and Evaluation Server hosts) |
| PostgreSQL | `externalPostgresql.hosts`, and optionally `.database`, `.username` |
| Redis (standard tier) | `externalRedis.hosts` |
| Optional | `architecture.tier` (`standalone` to run without Redis), `global.ingressClassName`, capacity settings |

PostgreSQL must already contain the schema for the FeatBit version being installed.

## Preview locally

From the repository root:

```bash
helm template featbit charts/featbit -f charts/featbit/examples/marketplace/values.yaml
```

The `<placeholder>` values render as-is, so this shows the full output without a real
cluster or customer settings.
