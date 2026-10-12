# FeatBit Helm Chart

[FeatBit](https://github.com/featbit/featbit) is an open-source feature flags management tool, which supported self-hosted deployment.
This Helm chart bootstraps a [FeatBit](https://github.com/featbit/featbit) installation on a [Kubernetes](https://kubernetes.io/) cluster using the [Helm](https://helm.sh/) package manager.

Current source: **Chart 0.10.0 / FeatBit 6.0.0**. The default UI/API/ELS image tags
are all `6.0.0`. Review the [0.10.0 migration guide](migration/RELEASE-v0.10.0.md)
before upgrading an existing installation.

## Architecture

The chart defines three core application services:

| Service | Container port | Purpose |
| --- | --- | --- |
| UI (`ui`) | 8081 | Management frontend |
| API Server (`api`) | 5000 | Management API and Insights queries |
| Evaluation Server (`els`) | 5100 | SDK synchronization, evaluation and event collection |

Use `architecture.tier: standard` or `professional`. Both use PostgreSQL (default)
or MongoDB for business data and Redis for caching. Standard uses the business
database for Insights and Redis for messaging. Professional adds Kafka for
messaging and ClickHouse for Insights; the API connects directly to ClickHouse.

## Prerequisites

* Kubernetes >=1.23
* Helm >= 3.7.0
* A valid JWT signing key; see [Required JWT Configuration](#required-jwt-configuration)
* External managed infrastructure and explicit `apiExternalUrl` /
  `evaluationServerExternalUrl` for production

## Usage 

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add featbit https://featbit.github.io/featbit-charts/
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
featbit` to see the charts.

From this repository root, install the current source for local development with
the bundled PostgreSQL/Redis example:

```bash
helm install featbit ./charts/featbit \
  --namespace featbit --create-namespace \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml
```

The local examples include a development-only JWT key. For MongoDB, use
[`featbit-standard-local-mongo.yaml`](charts/featbit/examples/standard/featbit-standard-local-mongo.yaml).
For Kafka/ClickHouse, use the [Professional example](charts/featbit/examples/pro/featbit-pro.yaml).
For production with external PostgreSQL/Redis, start from the
[AKS example](charts/featbit/examples/aks/README.md) and configure your own endpoints,
credentials and JWT Secret.

To install a packaged release, first check `helm search repo featbit/featbit --versions`
for availability. Git branch publication alone does not publish a chart package.
When `0.10.0` is available:

```bash
helm install featbit featbit/featbit --version 0.10.0 \
  --namespace featbit --create-namespace -f your-values.yaml
```

For an existing release, complete the manual schema migrations and values review
in the [0.10.0 migration guide](migration/RELEASE-v0.10.0.md) first. Prepare a complete
`migrated-values.yaml` with the desired external URLs, credentials, JWT, storage
and other overrides, then upgrade the current source:

```bash
helm upgrade featbit ./charts/featbit --namespace featbit \
  --reset-values -f migrated-values.yaml \
  --set-string ui.image.tag=6.0.0 \
  --set-string api.image.tag=6.0.0 \
  --set-string els.image.tag=6.0.0
```

For an available package, replace `./charts/featbit` with
`featbit/featbit --version 0.10.0`. Local overrides and `--reuse-values` can retain
old image tags and old defaults, including tags originally supplied by the old
chart. `appVersion` does not select these images. Explicitly updating all three
tags still requires reviewing removed values, new defaults and database migration;
it does not establish full compatibility of reused values.

To uninstall the chart:

```
helm uninstall <your-release-name> --namespace <your-namespace>
```

To get the more details of using helm to deploy or maintain your featbit release in the k8s, please refer to
Helm's [documentation](https://helm.sh/docs)

Note that if your device is based on the arm64 architecture, please use version 0.2.1 and above.

## Configuration

Beyond the chart's `values.yaml` parameters (architecture, external URLs, infrastructure, replicas, etc.), FeatBit services have many application-level settings that are **not** exposed in the chart by default. You can activate these capabilities by injecting environment variables via the `env` field on each service in your values file — for example `api.env` for the API server or `els.env` for the evaluation server:

```yaml
# in your values.yaml or -f override file
els:
  env:
    - name: SOME_ENV_VAR
      value: "some-value"
```

### Required JWT Configuration

FeatBit v5.3.4 and later require an explicit JWT signing key. The API will refuse to start when `Jwt__Key` is missing or still set to the chart's placeholder value.

For production, create a Kubernetes Secret in the FeatBit namespace:

```bash
kubectl create secret generic featbit-jwt-secret \
  --from-literal=jwt-key="$(openssl rand -hex 32)" \
  --namespace <your-featbit-namespace>
```

Then reference it in your values file:

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "HS256"
    - name: Jwt__Key
      valueFrom:
        secretKeyRef:
          name: featbit-jwt-secret
          key: jwt-key
```

> **Important:** Helm replaces lists instead of merging them. If you set any additional `api.env` entries, keep the required JWT entries in the same list.

### Example: CORS for Evaluation Server

**Problem**: Your frontend app is hosted on a different domain than the evaluation server, and the browser blocks SDK requests due to CORS policy.

By default, CORS is enabled with wildcard `*` for all origins, headers, and methods. If you need to restrict allowed origins for security:

```yaml
els:
  env:
    - name: Cors__AllowedOrigins
      value: "https://app.example.com;https://staging.example.com"
    - name: Cors__AllowCredentials
      value: "true"
```

> **Note**: `Cors__AllowCredentials: true` cannot be used with wildcard `*` origin — you must specify explicit origins.

See full CORS options: [evaluation-server README — CORS](https://github.com/featbit/featbit/tree/6.0.0/modules/evaluation-server#cors)

### Example: Rate Limiting for Evaluation Server

**Problem**: Your evaluation server is publicly exposed and you want to protect it from excessive traffic or abuse. By default, rate limiting is **disabled**.

Enable rate limiting with a fixed window of 100 requests per 60 seconds per environment:

```yaml
els:
  env:
    - name: RateLimiting__Enabled
      value: "true"
    - name: RateLimiting__Type
      value: "FixedWindow"
    - name: RateLimiting__PermitLimit
      value: "100"
    - name: RateLimiting__WindowSeconds
      value: "60"
```

For multi-instance deployments, enable distributed rate limiting backed by Redis:

```yaml
els:
  env:
    - name: RateLimiting__Enabled
      value: "true"
    - name: RateLimiting__Distributed
      value: "true"
    - name: CacheProvider
      value: "Redis"
```

You can also override limits per endpoint (e.g. `RateLimiting__Endpoints__Sdk__PermitLimit`). See full options: [evaluation-server README — Rate Limiting](https://github.com/featbit/featbit/tree/6.0.0/modules/evaluation-server#rate-limiting)

### Example: Hide Environment Secrets in the UI Header

FeatBit v5.4.9 adds `SHOW_ENV_SECRETS_IN_HEADER`, which defaults to `true`. To hide the
header's environment secrets popover, configure the UI environment variable:

```yaml
ui:
  env:
    - name: SHOW_ENV_SECRETS_IN_HEADER
      value: "false"
```

Use the quoted string `"false"` and retain any other `ui.env` entries in the same list.
Environment switching and access permissions are unchanged.

### Full Environment Variable Reference

- **UI** (`ui.env`): [modules/front-end/README.md](https://github.com/featbit/featbit/blob/6.0.0/modules/front-end/README.md) - UI runtime settings
- **API Server** (`api.env`): [modules/back-end/README.md](https://github.com/featbit/featbit/blob/6.0.0/modules/back-end/README.md) — JWT, Logging, OLAP, and more
- **Evaluation Server** (`els.env`): [modules/evaluation-server/README.md](https://github.com/featbit/featbit/blob/6.0.0/modules/evaluation-server/README.md) — Streaming, CORS, Rate Limiting, and more

### Professional ClickHouse configuration for v6

Chart `0.10.0` selects FeatBit `6.0.0` for UI/API/ELS. Fresh bundled initialization
is integrated; existing persistent/external databases require manual migration.
See the [release migration guide](migration/RELEASE-v0.10.0.md).
Offline rendering does not verify v6 startup or migration execution.

For `architecture.tier: professional`, the chart generates `OLAPProvider=ClickHouse`
and `ClickHouse__HttpEndpoint`, `ClickHouse__Database`, `ClickHouse__User` and
`ClickHouse__Password` on the API. Both API and ELS retain `MqProvider=Kafka` and
their existing business database and Redis settings. Standard leaves `OLAPProvider`
unset, so v6 Insights uses its selected `DbProvider` (Postgres or MongoDb), with
`MqProvider=Redis` on both backends. See the [official v6 provider configuration](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/ConfigurationExtensions.cs).

Bundled ClickHouse's API and startup wait share its HTTP Service endpoint and use
`clickhouse.database` and `clickhouse.auth.*`. The local development/test wait keeps
wget and supports HTTP only; Professional bundled TLS is rejected during rendering.
Keep `clickhouse.tls.enabled=false`. The default BusyBox image is unchanged.
External ClickHouse requires `externalClickhouse.httpEndpoint`, plus `database`, `user`,
and either `password` or `existingSecret` / `existingSecretKey`. An existing Secret
takes precedence; an inline password is placed in a chart-generated Secret.
An empty external password without a Secret generates an empty password value.
External HTTPS remains supported by the API with normal .NET certificate validation.
Old `host` / `httpPort` / `secure` settings must migrate to an absolute HTTP(S)
`httpEndpoint`; a missing endpoint fails rendering. No legacy fallback remains.

See the [release migration guide](migration/RELEASE-v0.10.0.md) for endpoint
examples, values changes and required Kafka topics. Use the chart values for generated
ClickHouse settings and avoid duplicating them in `api.env`.

## Expose self-hosted deployment

To use FeatBit, three services must be exposed from the internal network of Kubernetes:

* ui: FeatBit frontend
* api: FeatBit api server
* evaluation server(els): FeatBit data synchronization and data evaluation server

Set `apiExternalUrl` and `evaluationServerExternalUrl` in your values file to the
addresses reachable by the UI and SDK clients. Explicit external URLs are required
for production; the localhost defaults are for local access.

The exposure examples configure UI/API/ELS networking. Bundled infrastructure is
for development/test only. Current offline chart checks do not establish v6 runtime
or manual migration success. HPA examples require metrics-server.

### Ingress

Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

An Ingress may be configured to give Services externally-reachable URLs, load balance traffic, terminate SSL / TLS, and offer name-based virtual hosting. 

An Ingress controller is responsible for fulfilling the Ingress, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

#### Prerequisites
You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect.

You may need to deploy an Ingress controller such as ingress-nginx. You can choose from a number of [Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/).

Ideally, all Ingress controllers should fit the reference specification. In reality, the various Ingress controllers operate slightly differently.

Minikube supports ingress-nginx via addons, you can activate the ingress controller via:

```bash
minikube addons enable ingress
```

#### Example for Ingress

Here is a simple [example](./charts/featbit/examples/standard/expose-services-via-ingress.yaml) that show how to use ingress to expose services:
```yaml

apiExternalUrl: "http://{API host name}"
evaluationServerExternalUrl: "http://{Evaluation Server host name}"

ui:
  ingress:
    enabled: true
    host: {UI host name}


api:
  ingress:
    enabled: true
    host: {API host name}


els:
  ingress:
    enabled: true
    host: {Evaluation Server host name}


```

Note that:
* you should bind the host names that can be resolved by DNS server or map the IPs and host names in the dns hosts file(/etc/hosts in linux and macox) in your local cluster.
* the default ingress class is nginx, set your value in `global.ingressClassName` if needed
* set the annotations in the `<service>.ingress.annotations`, if needed
    for example:
    ``` yaml
    ... 
    ui:
      ingress:
          enabled: true
          host: {UI host name}
          annotations:
              nginx.ingress.kubernetes.io/use-regex: "true"
              nginx.ingress.kubernetes.io/rewrite-target: /$2
              kubernetes.io/tls-acme: "true"
    ...
      
    ```
#### Example for Ingress with TLS

Here is a simple [example](./charts/featbit/examples/standard/expose-services-via-tls-ingress.yaml) that show how to use ingress to expose services with TLS:
```yaml
apiExternalUrl: "https://{API host name, ex: api.featbit.com}"
evaluationServerExternalUrl: "https://{Evaluation Server host name, ex: api.featbit.com}"

ui:
  ingress:
    enabled: true
    host: {UI host name, ex: ui.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}

api:
  ingress:
    enabled: true
    host: {API host name, ex: api.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}


els:
  ingress:
    enabled: true
    host: {Evaluation Server host name, ex: els.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}
```

To create a secret for tls, we suggest you to use cert-manager to manage your auto-renewing ssl certificates, you can refer to [cert-manager](https://cert-manager.io/docs/) to get more details.

If you are using a self-signed certificate, you can create a secret with the following command:

```bash
kubectl create secret tls featbit-com-tls-secret --key /path/to/tls.key --cert /path/to/tls.crt
```

### LoadBalancer
Exposes the Service externally using an external load balancer. K8s does not directly offer a load balancing component; you must provide one, or you can integrate your Kubernetes cluster with a cloud provider.
Use known API/ELS addresses for explicit external URLs. For local development,
the chart also supports the LoadBalancer IP discovery configuration below.

#### Prerequisites

Minikube supports MetalLB to access the service with the external IP address

```bash
# get external ip binding to minikube
minikube ip
# enable the MetalLB minikube add-on.
minikube addons enable metallb
# Configure the external IPs ranges that can be used by MetalLB for the LoadBalancer services.
minikube addons configure metallb
```

#### Static IP
To expose service, we recommend you to bind static external IPs to services, as the following [example](./charts/featbit/examples/standard/expose-services-via-lb-static-ip.yaml)

```yaml

apiExternalUrl: "http://API_EXTERNAL_IP:5000"
evaluationServerExternalUrl: "http://ELS_EXTERNAL_IP:5100"

ui:
  service:
    type: LoadBalancer
    staticIP: {UI_EXTERNAL_IP}

api:
  service:
    type: LoadBalancer
    staticIP: {API_EXTERNAL_IP}

els:
  service:
    type: LoadBalancer
    staticIP: {ELS_EXTERNAL_IP}
```

#### IP Auto Discovery

We also provide a support to discovery automatically Load Balancer service IPs, as the following [example](./charts/featbit/examples/standard/expose-services-via-lb-auto-discovery-ip.yaml):

```yaml

apiExternalUrl: ""
evaluationServerExternalUrl: ""
autoDiscovery: true

ui:
  service:
    type: LoadBalancer

api:
  service:
    type: LoadBalancer

els:
  service:
    type: LoadBalancer
```
Use `kubectl get svc` to obtain the IP addresses.
Auto-discovery requires LoadBalancer services; it does not apply to ClusterIP,
NodePort or Ingress. Keep explicit API/ELS external URLs in production.

### NodePort
Exposes the Services on each k8s cluster Node's IP at a static port:

* ui: http://NODE_IP:30025
* api: http://NODE_IP:30050
* evaluation server(els): http://NODE_IP:30100

Set your configurations as the following [example](./charts/featbit/examples/standard/expose-services-via-nodeport.yaml)

```yaml

apiExternalUrl: "http://NODE_IP:30050"
evaluationServerExternalUrl: "http://NODE_IP:30100"

ui:
  service:
    type: NodePort
#    nodePort: 30025

api:
  service:
    type: NodePort
#    nodePort: 30050

els:
  service:
    type: NodePort
#    nodePort: 30100
```


It is generally advisable not to modify the default `nodePort` value unless it conflicts with your k8s node.

#### Get node's IP

Minikube: `minikube ip`


### ClusterIP

If you deployed the FeatBit chart in your cluster using the command `helm install featbit featbit/featbit`

By default, these three services are started using ClusterIP, which means they can only be accessed within the internal network of Kubernetes.

If you are using a single-node installation of Kubernetes cluster such as [Minikube](https://github.com/kubernetes/minikube) or [K3D](https://k3d.io/),

Please use the following command to expose the services, then visit ui in `http://localhost:8081`, set your [client sdk](https://docs.featbit.co/docs/getting-started/4.-connect-an-sdk) with `http://localhost:5100`

```
// ui
kubectl port-forward service/featbit-ui 8081:8081  [--namespace <your-name-space>]
// api
kubectl port-forward service/featbit-api 5000:5000 [--namespace <your-name-space>]
// evaluation server
kubectl port-forward service/featbit-els 5100:5100 [--namespace <your-name-space>]
```

## Migration and Upgrades

**Chart v0.10.0 / FeatBit v6.0.0**: See the [upgrade guide](./migration/RELEASE-v0.10.0.md).
This release uses three application images, removes `das.*`, `api.olapServiceHost`
and `OLAP__ServiceHost`, and moves Professional ClickHouse queries into the API.
External ClickHouse requires `externalClickhouse.httpEndpoint`. PostgreSQL/MongoDB
v6 schema migrations are required for existing databases; Professional also needs
adapted ClickHouse SQL and seven prepared Kafka topics.

🔄 **Starting from Helm Chart v0.9.0 (FeatBit v5.2.0)**

Release-specific instructions remain in [`migration/`](./migration/), including
the historical [0.9.17 guide](migration/RELEASE-v0.9.17.md). **Helm does not execute
existing-database migrations.** Fresh bundled installations use first-initialization
scripts; updating their ConfigMaps/Secrets does not upgrade initialized volumes.
Run the applicable incremental schema migration manually against the configured
database before using v6. Full bootstrap/seed scripts are for empty databases.

**For external databases**: Always check `migration/RELEASE-v{version}.md` for required database schema changes before running `helm upgrade`.

## ⚠️ Dependencies Notice

🚨 **CRITICAL: Bitnami Image Repository Changes (Effective August 2025)**

This chart includes infrastructure dependencies (PostgreSQL/MongoDB, Redis, Kafka, ClickHouse) which are **strictly for testing and development purposes** using bitnami legacy images with no updates.

The bundled PostgreSQL dependency is supported with its default authentication behavior and the settings exposed in [`charts/featbit/values.yaml`](./charts/featbit/values.yaml). Advanced Bitnami authentication overrides such as `global.postgresql.auth.*`, passwordless authentication, and custom `pg_hba.conf` configurations are outside the supported scope. Use `externalPostgresql` for non-standard or production PostgreSQL deployments.

**For local testing/development**, use the provided example configurations:
- [`featbit-standard-local-pg.yaml`](./charts/featbit/examples/standard/featbit-standard-local-pg.yaml) - PostgreSQL + Redis configuration for local Docker Desktop Kubernetes
- [`featbit-standard-local-mongo.yaml`](./charts/featbit/examples/standard/featbit-standard-local-mongo.yaml) - MongoDB + Redis configuration for local Docker Desktop Kubernetes

**Production environments must use external managed services** for the selected tier:
- **PostgreSQL/MongoDB**: Configure `externalPostgresql` or `externalMongodb` with managed database services (Azure Database for PostgreSQL, AWS RDS, Google Cloud SQL, etc.)
- **Redis**: Configure `externalRedis` with managed Redis services (Azure Cache for Redis, AWS ElastiCache, Google Cloud Memorystore, etc.)
- **Kafka**: Configure `externalKafka` with managed Kafka services (Confluent Cloud, AWS MSK, Azure Event Hubs, etc.)
- **ClickHouse**: Configure `externalClickhouse` with managed ClickHouse services (ClickHouse Cloud, Altinity.Cloud, etc.)

## Conclusion
We understand that not all service deployment methods may be compatible with your cluster. If you encounter any issues or need further assistance in exposing the services, please feel free to reach out to us for support. 
We'll be happy to help you with the specific configuration required for your cluster.
