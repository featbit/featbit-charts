# FeatBit Chart v0.10.0 / App v6.0.0 Migration Guide

**Thoroughly test the upgrade in an isolated environment before applying it to production; we recommend a blue-green deployment strategy with a tested rollback plan.**

Upgrade from Chart **0.9.17 / FeatBit 5.4.10** to **0.10.0 / 6.0.0**.
The application now uses three services: **UI, API and ELS**.

## Before upgrading

- Back up your databases and complete any outstanding
  [earlier migrations](RELEASE-v0.9.17.md).
- **Existing persistent and external databases require manual v6 schema migration.**
  Helm does not run these migrations.
- Fresh bundled installations initialize empty databases. Do not use their
  bootstrap/seed scripts to upgrade existing data.

## Update configuration

| Setting | Required action |
| --- | --- |
| `das.*` | Remove all DAS settings, including its image tag. |
| `api.olapServiceHost`, `OLAP__ServiceHost` | Remove from values and custom environment variables. |
| `externalClickhouse.host`, `httpPort`, `secure` | Replace with `externalClickhouse.httpEndpoint`. |
| `externalClickhouse.tcpPort`, `altHosts`, `cluster`, `verify` | Remove these obsolete settings. |

Professional requires ClickHouse. For local development with bundled ClickHouse,
set `clickhouse.enabled: true`, configure `clickhouse.database` and
`clickhouse.auth.*`, and keep `clickhouse.tls.enabled: false`.

For external ClickHouse, disable the bundled instance and configure:

```yaml
architecture:
  tier: professional
clickhouse:
  enabled: false
externalClickhouse:
  httpEndpoint: "https://clickhouse.example.com:8443"
  database: "your_analytics_database"
  user: "featbit-api"
  existingSecret: "featbit-clickhouse-password"
  existingSecretKey: "password"
```

Use the actual HTTP(S) endpoint, database and separate credentials. An existing
Secret takes precedence over `password`; use an existing Secret when all bundled
dependencies are disabled.

## Migrate databases manually

Run the applicable incremental script before starting v6. Stop on errors and
inspect partial changes before retrying.

| Database | Script | Required configuration |
| --- | --- | --- |
| PostgreSQL | [v6 SQL](../charts/featbit/files/featbit-v6/postgresql-v6.0.0.sql) | Change the initial `\connect featbit` to `externalPostgresql.database` or `postgresql.auth.database`. Use that same database in the client's connection. |
| MongoDB | [v6 JavaScript](../charts/featbit/files/featbit-v6/mongodb-v6.0.0.js) | Set `dbName` to `externalMongodb.database` or `mongodb.userDatabase.name`. |
| Professional ClickHouse | [v6 SQL](../charts/featbit/files/featbit-v6/clickhouse-v6.0.0.sql) | Adapt all SQL database names and Kafka broker, authentication, consumer group and topology settings to your deployment. |

For PostgreSQL, update **both** the SQL `\connect` target and the client's `--dbname`.
For ClickHouse, preserve consumer group offsets and tailor SQL for replicated/distributed
installations. Adapt SQL directly; API values do not update it. After manually migrating
bundled ClickHouse, set `clickhouse.initdbScriptsSecret: ""`.

Historical analytics/experiment data remains under legacy names; conversion is separate.

### Professional Kafka

Prepare these seven topics and their producer/consumer/group ACLs:

```text
featbit-feature-flag-change
featbit-segment-change
featbit-endusers
featbit-insights
featbit-usage
featbit-control-plane-web-hooks
healthchecks-topic
```

Bundled Kafka provisions all seven. Prepare external topics explicitly, including
with Control Plane disabled. For fresh bundled Kafka with auto-creation disabled,
omit `--wait` or prepare topics beforehand. Both producer and consumer principals
need WRITE/DESCRIBE on `healthchecks-topic`.
[Kafka ACL reference](https://kafka.apache.org/42/security/authorization-and-acls/).

## Values and image selection

Chart 0.10.0 already sets the UI/API/ELS image tags to `6.0.0`. If your overrides
pin old `ui.image.tag`, `api.image.tag` or `els.image.tag` values, update or remove
those pins. `--reuse-values` can retain old image tags and other defaults.
Changing `appVersion` alone does not update these images or make old values compatible.

Keep your existing JWT key, database/Redis credentials or Secret references,
persistence settings and API/ELS external URLs.

Helm rollback does not reverse database migrations.

## Verify the upgrade

Confirm UI/API/ELS use `6.0.0` and are healthy. Check login, existing SDK keys,
evaluations and live updates. For Professional, also check Kafka topics/ACLs and
ClickHouse ingestion and queries.
