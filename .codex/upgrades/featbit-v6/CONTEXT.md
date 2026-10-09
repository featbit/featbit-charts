# FeatBit v6.0.0 Upgrade Context

Recorded: 2026-10-08; updated: 2026-10-09 (Asia/Shanghai). This file contains decisions and diagnostic evidence for this upgrade. Progress is tracked in [TODO.md](TODO.md); operation history is in [WORKLOG.md](WORKLOG.md).

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
6. Store the plan and context in the project so new sessions can resume; TODO and WORKLOG track implementation progress.
7. Do not modify AGENTS.md. It belongs to the project, not to this task. Store task entry points, state and context in .codex and the dedicated skill; phase 5 also leaves AGENTS.md unchanged.
8. Use English only for communication, task records and skill instructions.
9. Use the requested `v6` branch for this upgrade.
10. The initial implementation request authorized V6-01 only. Preserve UI/API/ELS settings, shared Kafka/ClickHouse wait helpers, historical release/migration documents and private local AKS settings. Do not begin later phases, change versions, add the new ClickHouse provider configuration or edit database scripts. Its prohibition on deployment was subsequently extended only for the local smoke test in decision 12; external database operations remain unauthorized.
11. The R008 follow-up includes `featbit-aks-values.local.yaml` in DA cleanup. Preserve all non-DAS private settings and keep the file ignored; it is not part of the published chart changes. The other private AKS values file remains untouched.
12. On 2026-10-09, the user requested a local deployment trial and confirmed Docker Desktop Kubernetes rather than Docker Compose. Switch kubeconfig to `docker-desktop`, use a fresh local namespace and bundled test infrastructure, and test the current three-service chart. This authorizes local deployment/bootstrap only; no production/AKS deployment, external database operation or later upgrade phase is included.
13. The user subsequently requested login with the fresh test database's default account. Verify authentication in the existing local browser; the request does not include completing organization/project onboarding. Do not save the supplied password or session tokens in upgrade records.
14. The R011 request authorizes creating a test feature flag in the existing local project/environment, connecting the .NET SDK with the existing server key, and changing that flag to verify live notifications/evaluations. Reuse the local smoke deployment; no later upgrade phase or external database operation is included. Keep SDK keys out of source, records and screenshots.
15. The R012 request authorizes deleting the added temporary .NET SDK test program, including its generated files, and making one local commit for the completed V6-01 task. Preserve the verification results in these records. Keep the existing AGENTS.md edit outside the commit and private/local values ignored. No push, runtime cleanup or later phase is included.

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

## V6-01 verified state

Verified on 2026-10-08 from the actual chart and offline Helm output; see WORKLOG R007/R008.

- Restored `v6` with a clean working tree at `a4185bfe67898f6b4907bf8c85944d6389bb112b`, matching the local `origin/v6` tracking ref at R007. This reconciles R006's pending publication checkpoint with the committed publication-history repair. R012 records V6-01 in the local completion commit containing that worklog entry; resolve its SHA from Git history using the subject `refactor(helm): remove DA service (V6-01)`.
- Deleted the DAS Deployment, Service, HPA and test Pod templates. Removed the default `das` block, DAS service/image/pull-secret helpers, the UI's DAS wait and `api.olapServiceHost` / `OLAP__ServiceHost`.
- Removed DA-specific database, Kafka, ClickHouse and telemetry environment blocks. The API/ELS .NET database, Redis, Kafka and telemetry configuration is preserved. `clickhouse-usr-pass` remains for infrastructure initContainers, where `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` are still required; these are absent from application containers.
- Removed DAS overrides from six public examples and described UI/API/ELS in current architecture documentation. Updated the existing PostgreSQL password regression test for two .NET backends and absence of uppercase DA password variables.
- Six configuration cases passed Helm lint/template: Standard PostgreSQL, Standard MongoDB, Professional with bundled infrastructure, Standard api-only, Professional api-only and Professional with synthetic external infrastructure / existing Secrets. All six changed public examples also passed lint/template. Parsed comparisons against pre-change manifests confirmed that surviving Deployments and Services retain their configuration except for the requested DA removals.
- Active reference scans across the chart, current documentation, tests and workflows found no DAS dependency. Removed-value overrides do not recreate DAS or inject its pull Secret. Historical references remain in records, migration documents, the release skill awaiting V6-05 and the ignore rule protecting an old private values filename.
- R007 checksums confirmed 28 protected files were unchanged at that checkpoint, including AGENTS.md and both private AKS values files. In R008, removed only the DAS block and its heading from the requested `featbit-aks-values.local.yaml`; parsed comparison confirmed all other local values are identical. Both private files remain ignored, and the other private file is unchanged.
- R008 Helm lint/template with the private local AKS file passed. UI/API/ELS Deployments matched the pre-cleanup local render, with no DAS resources, DA-specific application environment variables or UI DAS wait. Helm output was captured only in memory; no private values or rendered manifests were printed or saved.
- An existing AGENTS.md edit changing its architecture description to three services was present at the start of R008. Left it untouched and verified its checksum did not change during the follow-up. Historical migrations, initialization scripts, versions, skills and shared infrastructure helpers have no additional changes.
- Existing Helm warnings about `redis.architecture` / `postgresql.architecture` remain unchanged. R007/R008 were offline checks; R009 subsequently verified local startup with the unchanged 5.4.10 images. v6 schema readiness, ingestion and end-to-end behavior remain unverified; this intermediate chart retains Chart `0.9.17` / App `5.4.10` and is not a completed v6 deployment.
- Next step when authorized: V6-02. Professional's new API `OLAPProvider` / `ClickHouse__*` configuration and decisions about legacy `externalClickhouse` fields/helpers remain pending. No later phase was started. R009's separate local smoke deployment is described below.

## Local startup, login and SDK smoke tests (R009–R011)

Verified on 2026-10-09. The user confirmed Docker Desktop Kubernetes and authorized a local deployment trial.

- Current kubeconfig context is `docker-desktop`; Docker context remains `desktop-linux`. The local Kubernetes node is Ready on v1.32.2. Cluster commands explicitly selected `docker-desktop`; AKS contexts and private AKS values were not used.
- Initial sandboxed access could not resolve `kubernetes.docker.internal`; host-side checks outside the sandbox reached the local cluster. Docker Desktop settings inspection initially reported Kubernetes disabled, and the user subsequently confirmed it enabled. The verified cluster state, rather than that earlier settings snapshot, is the current runtime evidence.
- Fresh namespace/release: `featbit-v6-01-smoke`. Installed the current chart with `examples/standard/featbit-standard-local-pg.yaml` plus the ignored `examples/standard/featbit-v6-01-smoke.local.yaml` override. Both paths are relative to `charts/featbit/`.
- The override uses ClusterIP services and ephemeral PostgreSQL/Redis storage. A random JWT signing key was generated directly into a namespace-scoped Secret; its value was not printed or saved. No existing data volume or external infrastructure is attached.
- Helm release revision 1 is `deployed`. UI/API/ELS Deployments and PostgreSQL/Redis StatefulSets are all 1/1 Ready, with zero pod restarts. No PVC exists in the test namespace. The installed Helm manifest contains no DAS or OLAP__ServiceHost reference.
- HTTP 200: API `/health/liveness` and `/health/readiness`, ELS `/health/liveness` and `/health/readiness`, UI `/health` and `/`. Loopback port forwards remain running: UI `http://localhost:18081`, API `http://localhost:15000`, ELS `http://localhost:15100`.
- R010 browser verification: submitted the user-supplied default login at `/en/login` and reached `http://localhost:18081/en/onboarding`. The account menu identifies the authenticated `tester`; the page displays "Create organization and project." Left the form unsubmitted and the authenticated browser open. Screenshot evidence is linked in WORKLOG R010.
- At R011, the UI already contained `test project` (`test-project`), with `Prod` (`prod`) selected and an existing server SDK key. Created the Boolean flag `local-dotnet-sdk-smoke` there. No additional organization, project, environment or SDK key was created.
- R011 SDK verification: FeatBit.ServerSdk 2.0.1 targeting .NET 8 initialized with `status=Ready` over `ws://localhost:15100`. The initial False evaluation had `kind=Off`; turning the flag ON and then saving its default rule as False produced two `DataChanged` patches with valid `kind=Fallthrough` evaluations: `False -> True -> False`. The same process handled both updates without polling or restart, then exited 0 and closed the SDK. Event/metric collection was disabled for this connectivity test.
- The flag is left ON with default rule False and OFF variation False. The authenticated browser, local release and port forwards remain available. R012 removed the temporary SDK harness and generated files at the user's request. Sanitized verification output and the screenshot link are retained in WORKLOG R011.
- Scope of runtime evidence: current 5.4.10 Standard/PostgreSQL startup, login, .NET SDK evaluation and live flag updates after DA cleanup. Insights, Professional/ClickHouse and actual v6 containers/schema were not tested. No manual SQL, migration, historical data processing or external database operation was executed. V6-06 remains unstarted because the complete v6 upgrade is pending.
- R009 added the ignored smoke override; R010 updated saved records; R011 used a temporary SDK harness; R012 removed that harness and prepared the local V6-01 completion commit with saved verification records. Chart versions, application image tags, schema scripts, AGENTS.md and private AKS values were left as found during these follow-ups. No later phase or push was performed. Keep the test release running for the user's review; see WORKLOG R009 for commands and cleanup information.

## Key files

| Area | Files |
| --- | --- |
| Default configuration/versions | `charts/featbit/values.yaml`, `charts/featbit/Chart.yaml` |
| Former DAS resources (deleted in V6-01) | `templates/da-server-{deployment,service,hpa}.yaml`, `templates/tests/das-test-connection.yaml` |
| Remaining image/service helpers | `templates/_helpers.tpl`, `templates/_svc_discovery_env.tpl` |
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
