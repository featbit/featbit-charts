# FeatBit v6.0.0 Upgrade Context

Recorded: 2026-10-08 (Asia/Shanghai). This file contains decisions and diagnostic evidence for this upgrade. Progress is tracked in [TODO.md](TODO.md); operation history is in [WORKLOG.md](WORKLOG.md).

## Baseline and target

- Repository: `featbit/featbit-charts`.
- Diagnostic baseline commit: `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b`; the branch was `main` and the working tree was clean at diagnosis.
- Upgrade branch: `v6`, initially created from the diagnostic baseline on 2026-10-08, then rebased onto published chart commit `f78ba88a96eefa485517c7fb54bd2bc8395ab907` before publication. The private local AKS setup commit was excluded after GitHub push protection rejected its credentials; the original local `main` branch was preserved. Verify the current branch before continuing.
- Chart baseline: `0.9.17`; application baseline: `5.4.10`; target application: `6.0.0`.
- Upstream application tag `5.4.10`: `100d585e481fca3413468cbc6a9c70eb5246cc60`.
- Upstream application tag `6.0.0`: `21b2af4feb3658a88b82349e1b31fff78ab0966c`.
- The target chart version is undecided. Determine it from final values compatibility rather than assuming the application major version dictates the chart major version.
- Local AKS values currently use `standard + postgres`. This records configuration structure only; the deployed environment has not been verified.
- The two local AKS `.local.yaml` files remain on disk and are ignored by the upstream `.gitignore`. Keep them private and do not reintroduce commit `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b` into the published upgrade history.

## User-confirmed decisions

1. Address the upgrade step by step, starting with complete removal of the DA service and its associated configuration.
2. Exclude `SHOW_ENV_SECRETS_IN_HEADER`. It was removed in the new version and is only a generic `ui.env` passthrough, without a dedicated Helm value.
3. Do not enable Control Plane while it remains incomplete; do not add its services, optional configuration or deployment workflow.
4. Historical experiment conversion, migration to the new model and historical report recovery use separate scripts/programs. Customers can contact FeatBit when needed.
5. The schema required to start v6 and chart initialization script integration remain in scope, distinct from the data conversion in decision 4.
6. Store the plan and context in the project so new sessions can resume. No chart upgrade phase has been implemented yet.
7. Do not modify AGENTS.md. It belongs to the project, not to this task. Store task entry points, state and context in .codex and the dedicated skill; phase 5 also leaves AGENTS.md unchanged.
8. Use English only for communication, task records and skill instructions.
9. Use the requested `v6` branch for this upgrade.

Update this section and WORKLOG when the user changes scope. The current request and authorization take precedence over an older saved plan.

## Verified configuration changes

| Item | Diagnostic finding | Phase |
| --- | --- | --- |
| DA Server | v6 retires `featbit/featbit-data-analytics-server`; the core architecture becomes UI/API/ELS. | V6-01 |
| API -> DAS | `OLAP__ServiceHost` is removed; remove the existing `api.olapServiceHost` value and rendering logic. | V6-01 |
| Python environment variables | Shared templates still inject DA-specific `DB_PROVIDER`, `POSTGRES_*`, `MONGO_*` and related fields; retain their .NET counterparts. | V6-01 |
| Professional OLAP | The API adds `OLAPProvider`, falling back to `DbProvider` when unset; Professional must select ClickHouse. | V6-02 |
| ClickHouse connection | The API uses `ClickHouse__HttpEndpoint/Database/User/Password`. Selecting ClickHouse validates `MqProvider=Kafka` and a required HTTP endpoint. | V6-02 |
| ClickHouse topology parameters | New API options lack altHosts/cluster/verify/replication switches; old DAS parameters cannot simply be renamed. | V6-02/03 |
| ClickHouse initialization | Official SQL defaults to a single node and fixed `featbit`, `kafka:9092`, `featbit-insights` and `ch_group` settings. Helm values do not rewrite SQL; replicated/distributed layouts need adaptation. | V6-03 |
| Default Kafka subscriptions | The v6 API AddKafka subscription list includes `featbit-control-plane-web-hooks` without a Control Plane condition. Check topics/ACLs when automatic topic creation is disabled; this does not expand scope to enabling Control Plane. | V6-02 |
| Initialization ConfigMaps | This repository's PostgreSQL/MongoDB scripts include changes only through v5.4.1. Updating an initialization ConfigMap does not migrate existing data volumes. | V6-03 |
| Compatible parameters | PostgreSQL/MongoDB/Redis connection fields, .NET Kafka fields, JWT, SSO, CORS, RateLimiting and UI URL/BASE_HREF/display URL/HOSTING_MODE remain compatible. HOSTING_MODE is not new in v6. | Verify as needed |
| UI startup interface | v6 retains `/scripts/docker-entrypoint.sh` and `/health`; the chart's setup.sh wrapper can still connect to them. Remove the DAS wait logic. | V6-01/06 |
| InsightsTracking | The API adds FlushIntervalMs/ChannelCapacity/MaxBatchSize, defaulting to 1000/10000/1000. They can be set through api.env without mandatory new values. | Verify as needed |

Required schema changes can include experiment tables; use the official scripts. Archiving old data does not convert it, so database upgrade completion must not be reported as successful historical experiment migration.

## Key files

| Area | Files |
| --- | --- |
| Default configuration/versions | `charts/featbit/values.yaml`, `charts/featbit/Chart.yaml` |
| DAS resources | `templates/da-server-{deployment,service,hpa}.yaml`, `templates/tests/das-test-connection.yaml` |
| DAS helpers | `templates/_helpers.tpl`, `templates/_svc_discovery_env.tpl` |
| UI dependency waits | `templates/_initContainers-wait-for-other-components.tpl` |
| API OLAP configuration | `templates/api-deployment.yaml` |
| Environment variables | `templates/_postgresql-env.tpl`, `_mongodb-env.tpl`, `_pro-env.tpl`, `_otel-env.tpl` |
| Helpers to retain | `kafka-bootstrapservers` in `_pro-env.tpl`, and `clickhouse-usr-pass` called by infrastructure wait templates |
| ClickHouse configuration | `templates/_clickhouse-config.tpl`, `templates/clickhouse-external-secret.yaml` |
| New installation initialization | `templates/postgresql-init-scripts-configmap.yaml`, `templates/mongodb-init-scripts-configmap.yaml` |
| Current examples | `charts/featbit/examples/` |
| AKS configuration | `charts/featbit/examples/aks/featbit-aks-values.local.yaml` |
| Migration instructions | `migration/RELEASE-v{chart-version}.md` |
| General release skill | `.agents/skills/upgrade-featbit-chart/SKILL.md` (frontmatter name: `new-featbit-release`) |

Template paths in this table are relative to `charts/featbit/`. The general release skill still describes four images; this upgrade uses three core services. Update the general skill in V6-05.

## Evidence and references

- [Upgrade guide supplied by the user](https://docs.featbit.co/installation/upgrade/upgrade-to-v6)
- [Official guide source snapshot used for diagnosis](https://github.com/featbit/featbit-docs/blob/d5cbcd9fc27f4eb24761fa19495d3f23d4178fff/content/docs/installation/upgrade/upgrade-to-v6.mdx): the guide webpage could not be read, so diagnosis used its official documentation repository source.
- [v6.0.0 release notes](https://github.com/featbit/featbit/releases/tag/6.0.0)
- [v6 API configuration](https://github.com/featbit/featbit/blob/6.0.0/modules/back-end/README.md)
- [ClickHouse options](https://github.com/featbit/featbit/blob/6.0.0/modules/back-end/src/Infrastructure/OLAP/ClickHouse/ClickHouseOptions.cs) and [startup validation](https://github.com/featbit/featbit/blob/6.0.0/modules/back-end/src/Infrastructure/ServiceCollectionExtensions.cs)
- [Default API MQ subscriptions](https://github.com/featbit/featbit/blob/6.0.0/modules/back-end/src/Infrastructure/MQ/MqServiceCollectionExtensions.cs)
- [v6 UI configuration](https://github.com/featbit/featbit/blob/6.0.0/modules/front-end/README.md)
- [PostgreSQL schema](https://github.com/featbit/featbit/blob/6.0.0/infra/postgresql/docker-entrypoint-initdb.d/v6.0.0.sql)
- [MongoDB schema](https://github.com/featbit/featbit/blob/6.0.0/infra/mongodb/docker-entrypoint-initdb.d/v6.0.0.js)
- [ClickHouse schema](https://github.com/featbit/featbit/blob/6.0.0/infra/clickhouse/docker-entrypoint-initdb.d/v6.0.0.sql)

Read the sources relevant to the current phase; a new session does not need to repeat the full diagnosis. Verify and record any differences between saved evidence and actual code or sources.

## Project constraints

Production uses external managed infrastructure and requires external URLs. Database migrations are manual. Built-in dependencies are for development/test only. Read AGENTS.md for project rules and follow the user's current instructions without modifying AGENTS.md for this task.

Record configuration structure, key names and verification summaries. Do not copy real connection details, credentials, certificates or complete rendered output containing passwords from local values into these files.
