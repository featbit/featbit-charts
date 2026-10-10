# Professional ClickHouse configuration

This is the V6-02 configuration checkpoint on the `v6` branch. Chart/app versions
and images remain `0.9.17` / `5.4.10`. v6 schema integration and runtime validation
are pending; these examples are not evidence of a working v6 installation.
Bundled dependencies are for development/test. Production uses managed external
infrastructure and explicit API/ELS external URLs.

## API connection values

With `architecture.tier: professional`, the API selects `OLAPProvider=ClickHouse`.
`DbProvider` still selects PostgreSQL or MongoDB for business data; API and ELS both
use `MqProvider=Kafka`. Standard omits the ClickHouse environment block and lets
Insights default to its business database.

For an external HTTP interface:

```yaml
clickhouse:
  enabled: false
externalClickhouse:
  httpEndpoint: "https://clickhouse.example.com:8443"
  database: "analytics"
  user: "insights-reader"
  existingSecret: "featbit-clickhouse-password"
  existingSecretKey: "password"
```

Use an absolute `http://` or `https://` URL, optionally with a path, without embedded
credentials, query parameters or a fragment. The v6 client puts the configured
database in the query string and sends the separate user/password with HTTP Basic
authentication. Use ClickHouse's HTTP(S) listener, not its native TCP listener.
`externalClickhouse.httpEndpoint` is required when Professional uses external
ClickHouse. Missing or empty endpoints fail rendering with a migration message;
legacy host/port/TLS fields do not supply a fallback.
[Source: v6 ClickHouse client](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/OLAP/ClickHouse/ClickHouseClient.cs).

An existing Secret must be in the release namespace. It overrides `password` and
is referenced directly by the API. External ClickHouse has no ClickHouse startup
wait and no ClickHouse credentials are injected into the infrastructure wait
containers. Alternatively,
set `externalClickhouse.password` inline: the chart stores it in a generated Secret
and uses `secretKeyRef`. Empty password with no Secret uses an empty string and
does not reference a nonexistent Secret.

Bundled ClickHouse derives the endpoint from the actual subchart Service name and
`clickhouse.service.ports.http`. The Professional bundled startup wait supports
HTTP only; keep `clickhouse.tls.enabled=false`. `clickhouse.database` selects the query database;
`clickhouse.auth.username`, `password`, `existingSecret` and `existingSecretKey`
select credentials shared with the subchart. Its wait helper still checks the
configured `featbit_ch_cluster` node count (`shards * replicaCount`). The API and
startup wait use the same `featbit.clickhouse.httpEndpoint` helper, including the
Service name, scheme and Service port. The wait runs only for Professional with
bundled ClickHouse enabled, in the existing API/ELS infrastructure initContainers.
Credentials stay in their existing environment/Secret references; the wait sends
a separate Basic-auth header rather than putting them in the URL. Quoted shell
expansions preserve password punctuation and newlines.
Bundled wait credentials come from `clickhouse-usr-pass` in `_pro-env.tpl`, included
only when the bundled ClickHouse wait is enabled. API connection settings remain
in `_clickhouse-env.tpl`. See the
[template layout guide](../../TEMPLATES.md) for the application, bundled dependency
and shared-helper boundaries across all five infrastructure services.
Generated host/Secret names follow the subchart's naming rules, including an empty
or release-matching `nameOverride`; explicit existing Secret names are unchanged.

### Bundled HTTP startup wait

Bundled dependencies provide a quick local development/test environment. The
ClickHouse wait keeps wget and the existing cluster node-count query, using the
same HTTP endpoint as the API. No curl or image override is required. Professional
with bundled ClickHouse and `clickhouse.tls.enabled=true` fails rendering with an
HTTP-only diagnostic; it never falls back to unverified HTTPS or a different URL.

The unchanged default image is `docker.io/busybox:1.34`; its internal wget TLS
implementation does not validate server certificates. Supporting bundled HTTPS
would require additional client/trust setup, outside this local wait's scope.
[BusyBox 1.34.1 wget source](https://github.com/mirror/busybox/blob/1_34_1/networking/wget.c),
[official 1.34 image build](https://github.com/docker-library/busybox/blob/a04e2746f8704ea7418f17af4ca8b7001e54b29e/stable/uclibc/Dockerfile.builder),
[tag mapping](https://github.com/docker-library/official-images/blob/5810102899397f32a4def86dcf59d7e0ec72a806/library/busybox).

External ClickHouse continues to accept HTTP or HTTPS endpoints and has no
ClickHouse startup wait. For HTTPS, the API must trust the server's certificate
chain and hostname through normal .NET validation. Rendering does not verify an
actual TLS handshake. Default image values and tags are unchanged.

These settings do not create databases, change Kafka ingestion or rewrite SQL.
Non-default database names and clustered ClickHouse layouts require matching,
manually adapted schema scripts in V6-03. See the [official ClickHouse upgrade guidance](https://docs.featbit.co/installation/upgrade/upgrade-to-v6#clickhouse-changes).

## Legacy externalClickhouse values

| Value | V6-02 behavior / migration |
| --- | --- |
| `host`, `httpPort`, `secure` | Removed from defaults and ignored by templates. Replace them with `httpEndpoint`, including `http://` or `https://`, the HTTP(S) host and the listener's actual port. Missing `httpEndpoint` is a rendering error. |
| `tcpPort` | Removed from defaults and unused TCP helper; select the HTTP(S) endpoint instead. |
| `altHosts` | Removed from defaults and unused helper; use a reachable HTTP routing/load-balancer endpoint. |
| `cluster` | Removed from defaults; v6 API options have no DDL/topology setting. Retain the actual cluster layout in server configuration and tailored SQL. |
| `verify` | Removed from defaults; the v6 API has no bypass option. HTTPS uses normal .NET certificate validation. Install a trusted CA/certificate when needed. |

Removed fields supplied through old files or `--reuse-values` are inert. They do
not configure the API or satisfy the required endpoint. For example, old
`host: clickhouse.example.com`, `httpPort: 8443`, `secure: true` must become
`httpEndpoint: "https://clickhouse.example.com:8443"`; a plaintext HTTP listener
uses `http://` and its actual HTTP port. TCP TLS and HTTP TLS are separate
listeners; no port conversion is performed. Shared Kafka connection/authentication
and ClickHouse fullname, database, credential and Secret helpers remain.
[Source: v6 ClickHouse options](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/OLAP/ClickHouse/ClickHouseOptions.cs).

## Kafka requirements with Control Plane disabled

The tagged `6.0.0` source subscribes the API to three topics unconditionally for
Kafka. Disabling Control Plane does not remove its web-hooks subscription:

| Client | Default topics | Consumer group |
| --- | --- | --- |
| API consumer | `featbit-endusers`, `featbit-usage`, `featbit-control-plane-web-hooks` | `featbit-api` (overridable with `Kafka__Consumer__group.id` in `api.env`) |
| ELS consumer | `featbit-feature-flag-change`, `featbit-segment-change` | A new `evaluation-server-<GUID>` per process; allow that group prefix. |
| ClickHouse ingestion | `featbit-insights` | Official v6 SQL defaults to `ch_group`; adapt SQL for your actual group/topology. |

Evidence: [API subscriptions](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/MQ/MqServiceCollectionExtensions.cs),
[API group defaults](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Api/appsettings.json),
[ELS subscriptions/group](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/evaluation-server/src/Infrastructure/MQ/Kafka/KafkaMessageConsumer.cs),
and [ClickHouse SQL](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/infra/clickhouse/docker-entrypoint-initdb.d/v6.0.0.sql).

The API does not subscribe to `featbit-insights` in Kafka mode; ClickHouse handles
that ingestion. ELS adds `featbit-control-plane-command` only when Control Plane
is enabled. No other Control Plane topic/service is required by these default
consumers while it is disabled.
The API also registers the web-hooks handler unconditionally; matching-region
messages can be handled while Control Plane is disabled. This is a requirement
of the existing consumer path, not an instruction to enable Control Plane.
[Web-hooks handler source](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/MQ/ControlPlaneWebHooksMessageHandler.cs).

For ACL-enabled Kafka, consumers need topic READ/DESCRIBE and group READ (including
offset operations). Producers need WRITE/DESCRIBE on the topics they publish to:
API flag/segment notifications and ELS endusers/insights/usage. Map permissions to
the configured producer and consumer principals, including ClickHouse's own
ingestion principal. Additional producer settings can require extra permissions
(for example idempotent or transactional production).
[Kafka ACL reference](https://kafka.apache.org/42/security/authorization-and-acls/).
Publishing paths: [API flag notifications](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Application/FeatureFlags/FlagChangePublisher.cs)
and [ELS tracking](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/evaluation-server/src/Api/Public/InsightController.cs).

API/ELS Kafka readiness checks also use `healthchecks-topic` with producers built
from **both** the producer and consumer configuration. Both principals therefore
need WRITE/DESCRIBE there, even if the consumer otherwise only reads.
[API health-check source](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/back-end/src/Infrastructure/MQ/Kafka/KafkaHealthCheckBuilderExtensions.cs),
[ELS health-check source](https://github.com/featbit/featbit/blob/21b2af4feb3658a88b82349e1b31fff78ab0966c/modules/evaluation-server/src/Infrastructure/MQ/Kafka/KafkaHealthCheckBuilderExtensions.cs),
[9.0.0 health-check implementation](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks/blob/release-all-9.0.0/src/HealthChecks.Kafka/KafkaHealthCheck.cs).

If broker/topic auto-creation is disabled, arrange all seven listed topic names
(including `healthchecks-topic`) before v6 startup. The existing bundled
`kafka.provisioning.topics` list has four of them; it is unchanged in V6-02.
Auto-creation, when allowed, also needs the relevant CREATE permission. Missing
topics/ACLs can cause consumption or readiness errors; rendering cannot verify
them. This phase records requirements only and does not provision Kafka resources
or enable Control Plane.
