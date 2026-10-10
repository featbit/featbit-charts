# Template layout and infrastructure settings

Separate the server that Helm deploys from the connection configuration that
FeatBit consumes. The application needs connection settings for both bundled and
external infrastructure; only bundled infrastructure needs this chart's server
deployment and startup waits. Production uses external managed services. Bundled
dependencies are for development/test.

## Values: bundled server or external connection

| Service | Bundled settings in values.yaml | External connection settings | Application connection templates |
| --- | --- | --- | --- |
| PostgreSQL | `postgresql.*` | `externalPostgresql.*` | `templates/_postgresql-config.tpl`, `templates/_postgresql-env.tpl` |
| MongoDB | `mongodb.*` | `externalMongodb.*` | `templates/_mongodb-config.tpl`, `templates/_mongodb-env.tpl` |
| Redis | `redis.*` | `externalRedis.*` | `templates/_redis-config.tpl`, `templates/_redis-env.tpl` |
| Kafka | `kafka.*` | `externalKafka.*` | `templates/_kafka-config.tpl`, `kafka-bootstrapservers` in `templates/_pro-env.tpl` |
| ClickHouse | `clickhouse.*` | `externalClickhouse.*` | `templates/_clickhouse-config.tpl`, `templates/_clickhouse-env.tpl` |

Each bundled block's `enabled` value controls deployment of its dependency chart
declared in [Chart.yaml](Chart.yaml). If disabled, the shared connection helpers
use the corresponding external block where that service is needed. For external
Professional ClickHouse, `externalClickhouse.httpEndpoint` is required.

Some bundled-block values are also application inputs. For example,
`clickhouse.database` selects the API query database; it does not create a database
or change initialization scripts. The `*-config.tpl` and `*-env.tpl` files resolve
these connection inputs for the application.

The architecture and tier decide which services the application uses:
`architecture.database` selects PostgreSQL or MongoDB; Standard uses Redis for
messaging, while Professional uses Kafka and ClickHouse for Insights. Enabling a
dependency alone does not select the application's database or provider.

## Templates by responsibility

| File group | Responsibility | Bundled/external scope |
| --- | --- | --- |
| `templates/_*-config.tpl` for the five services | Resolve addresses, database/user settings and Secret names/keys. These are shared connection helpers, not server deployment templates. | Both, selected from values |
| `templates/_postgresql-env.tpl`, `_mongodb-env.tpl`, `_redis-env.tpl`, `_clickhouse-env.tpl` | Turn connection settings into environment variables for the API/ELS application containers. ClickHouse's block is used only by the Professional API. | Both |
| `templates/_pro-env.tpl` | `kafka-bootstrapservers` supplies Professional API/ELS application settings for bundled or external Kafka. `clickhouse-usr-pass` supplies credentials to the bundled ClickHouse startup wait. The caller determines which container receives each block. | Kafka: both; ClickHouse wait credentials: bundled only |
| `templates/_initContainers-wait-for-infrastructure-dependencies.tpl` | Generate the existing API/ELS startup wait. PostgreSQL/MongoDB/Redis use TCP probes when selected and enabled; Kafka and ClickHouse waits additionally require Professional. ClickHouse uses an authenticated cluster node-count check. | Probes only enabled bundled dependencies |
| `templates/_initContainers-wait-for-other-components.tpl` | Wait for FeatBit application components, separately from infrastructure startup. | Application components |
| `templates/postgresql-init-scripts-configmap.yaml`, `templates/mongodb-init-scripts-configmap.yaml` | Supply initialization scripts for new bundled database instances. They do not migrate existing external databases. | Bundled only |
| `templates/*-external-secret.yaml` | Store inline external passwords in Kubernetes Secrets when required; reuse an explicitly configured existing Secret. These templates do not deploy database/cache/broker servers. | External connections |
| `templates/mongodb-conn-string-secret.yaml` | Supply a MongoDB connection-string Secret when the MongoDB helpers require one. | Bundled or external, according to helper settings |
| `templates/api-*.yaml`, `templates/eval-server-*.yaml`, `templates/ui-*.yaml` | Define FeatBit application resources, including Deployments, Services and related configuration. | Application components |
| `templates/_helpers.tpl`, `templates/_images.tpl`, `templates/_svc_discovery_env.tpl`, `templates/_otel-env.tpl` | Shared chart naming/metadata, images, application service discovery and telemetry configuration. | General chart/application helpers |

Bundled PostgreSQL, MongoDB, Redis, Kafka and ClickHouse workload manifests come
from their dependency charts in `charts/`. Their server settings belong under the
bundled values blocks, rather than the application `env` templates. The ClickHouse
server configuration override also lives under `clickhouse` in values.yaml.

## ClickHouse example: two consumers of one connection configuration

- The Professional API uses `_clickhouse-env.tpl`: `OLAPProvider` and
  `ClickHouse__HttpEndpoint/Database/User/Password` for Insights queries. This applies
  to bundled and external ClickHouse, including passwordless external connections.
- The infrastructure startup wait includes `clickhouse-usr-pass` from
  `_pro-env.tpl` for `CLICKHOUSE_USER` and `CLICKHOUSE_PASSWORD`. The include is
  enabled only when Professional and bundled ClickHouse are both enabled. Bundled
  passwords use the subchart's generated or configured Secret.
- Both use `_clickhouse-config.tpl` to resolve the same endpoint and credentials.
  An external HTTP endpoint has no ClickHouse node-count wait and its password
  Secret is not passed to the wait container.

The existing `_pro-env.tpl` file and both helper definitions are retained.
It serves two callers with different purposes: API/ELS application containers use
the Kafka helper, while bundled ClickHouse startup waits use the credential helper.
The unused external ClickHouse credentials are excluded at the wait's call site.

The infrastructure initContainer itself is still generated by the existing
application Deployments; this refactor scopes its probes and credentials, without
removing the container when every dependency is external. Bundled Professional
ClickHouse waiting supports HTTP only; external API connections still support
HTTP/HTTPS. See the
[Professional configuration guide](examples/pro/README.md#bundled-http-startup-wait).
