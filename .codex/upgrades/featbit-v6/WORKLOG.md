# FeatBit v6.0.0 Upgrade Worklog

Append entries chronologically. [TODO.md](TODO.md) tracks progress; [CONTEXT.md](CONTEXT.md) holds scope and evidence. Use Asia/Shanghai dates and English only. Record files, commands, results, unverified items and the next step whenever work, scope or phase acceptance changes.

## 2026-10-08 · R001 · Diagnosis and scope confirmation

- Baseline: Chart 0.9.17 / App 5.4.10, repository commit `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b`.
- Compared the official v6 guide source, release notes, application configuration at tags 5.4.10/6.0.0 and the existing chart.
- Confirmed DAS retirement, removal of OLAP__ServiceHost, new Professional API ClickHouse parameters and missing initialization scripts.
- The user chose DA cleanup first and excluded SHOW_ENV_SECRETS_IN_HEADER, enabling Control Plane and historical experiment data conversion.
- No chart, application version or existing release skill changes; no database scripts or deployments executed.

### Offline diagnostic commands

```powershell
helm template v6diagnostic charts/featbit --set ui.image.tag=6.0.0 --set api.image.tag=6.0.0 --set els.image.tag=6.0.0 --set das.enabled=false

helm template v6diagnostic charts/featbit --set architecture.tier=professional --set kafka.enabled=true --set clickhouse.enabled=true --set ui.image.tag=6.0.0 --set api.image.tag=6.0.0 --set els.image.tag=6.0.0 --set das.enabled=false
```

Results: both commands exited 0. OLAP__ServiceHost was still rendered; Professional lacked OLAPProvider and ClickHouse__HttpEndpoint; v6 initialization scripts were absent. Helm emitted dependency merge warnings for redis/postgresql.architecture; these were not treated as new v6 issues.

These checks establish the original chart's rendering behavior only. Container startup, database migration, development deployment and end-to-end behavior were not verified.

Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R002 · Create persistent records and a resume skill

- Added `.codex/upgrades/featbit-v6/TODO.md`, `CONTEXT.md` and `WORKLOG.md`.
- Added the project skill `.agents/skills/featbit-v6-upgrade/SKILL.md`.
- Added a conditional upgrade entry point to AGENTS.md for restoring the plan, decisions and latest worklog. This change was reverted in R003.
- Verification: skill-creator's `quick_validate.py` passed; UTF-8 and 15 local references across five files passed; new document whitespace checks and `git diff --check` passed. Existing AGENTS.md Markdown line-break spaces were preserved.
- No changes to the chart, existing release skill or application versions; no deployment or database operations.
- Git state at this entry: AGENTS.md modified and four new untracked files; changes uncommitted.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R003 · Revert task changes to the project rules file

- The user explicitly required AGENTS.md to remain unchanged because it belongs to the project rather than this task.
- Reverted only the upgrade entry point added in R002. Restored AGENTS.md to its saved original bytes; `git diff --exit-code -- AGENTS.md` passed.
- Updated TODO, CONTEXT and the dedicated skill with this constraint; removed project rule changes from V6-05.
- Kept R002 as history and marked its AGENTS.md change as reverted. Retained the persistent records and skill; new sessions can invoke `$featbit-v6-upgrade`.
- No chart upgrade phase implemented; no deployment or database operations. The four task files remained uncommitted.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R004 · Create the v6 branch and adopt English

- The user requested English only and a `v6` branch for this upgrade.
- Ran `git switch -c v6` from `main` at `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b`; the branch was created and checked out, preserving the existing task files.
- Translated TODO, CONTEXT, WORKLOG and `.agents/skills/featbit-v6-upgrade/SKILL.md` into English, preserving phase status, decisions, evidence and historical entries.
- Saved the English-only preference and branch in the records and resume skill.
- Verification: `git branch --show-current` returned `v6`; skill-creator's `quick_validate.py` passed. English-only UTF-8 content, whitespace and 11 local links across the four task files passed validation. `git diff --check` passed, and AGENTS.md SHA256 remained `a7994f1ed795d3d9fd0522ecd4d11f91285d8f71244f0eb2c768a0937d09b6cf`.
- Chart implementation remains unstarted. The four task files are uncommitted; no deployment or database operations.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R005 · Prepare publication and the V6-01 handoff

- The user authorized committing and pushing the upgrade setup on `v6`, then requested a prompt for implementing the first TODO phase in a new session.
- Updated the latest request in TODO; all implementation phases remain unstarted.
- Commit scope: `.codex/upgrades/featbit-v6/TODO.md`, `CONTEXT.md`, `WORKLOG.md` and `.agents/skills/featbit-v6-upgrade/SKILL.md`.
- Before publication, `git status` showed only those four untracked files; `git ls-remote --heads origin refs/heads/v6` found no remote branch. AGENTS.md matched its original SHA256 and had no Git diff.
- Publication commands: stage the four files, commit as `chore: persist FeatBit v6 upgrade plan`, then `git push --set-upstream origin v6`.
- At entry preparation the setup files are uncommitted. Use Git history and the remote branch to recover the resulting commit and publication status before resuming.
- Next session: invoke `$featbit-v6-upgrade`, implement V6-01 only, validate Standard / Professional / api-only rendering and update the saved records. Preserve the exclusions and leave AGENTS.md unchanged.

## 2026-10-08 · R006 · Separate private local settings from published history

- GitHub rejected the first push because ancestor commit `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b` contained OAuth configuration in the local AKS values file. The four new upgrade records were not the source of the rejection.
- That ancestor contained two local AKS configuration files and changes disabling their ignore rules. Preserved the original `main` branch, backed up both private files and restored them locally with matching SHA256 hashes.
- Rebased the unpublished `v6` branch onto `f78ba88a96eefa485517c7fb54bd2bc8395ab907`, verified to be in published `origin/main` history. The upgrade setup commit became `3dfa859ac9f1d914ddce83dcd22d55a3a97df71a`.
- The upstream ignore rules are active on `v6`; both private files are ignored. Verified that the credential-containing ancestor is absent from `v6` and that the original `main` branch is unchanged.
- Updated TODO and CONTEXT with the published branch base and private-file handling. AGENTS.md still matches its original SHA256. Chart upgrade phases remain unstarted.
- Next operation: commit this checkpoint, retry `git push --set-upstream origin v6` and verify the remote tip. At entry preparation this checkpoint is uncommitted; recover final commit and publication status from Git.
- Next implementation step: V6-01 only.

## 2026-10-08 · R007 · V6-01 implementation and verification

- Restored the skill, TODO, CONTEXT, WORKLOG and project rules. Actual branch: `v6`; starting working tree: clean; HEAD and the local `origin/v6` tracking ref: `a4185bfe67898f6b4907bf8c85944d6389bb112b` (`docs: record v6 publication history repair`). R006's publication checkpoint is now reconciled with Git history.
- The user authorized V6-01 only. V6-01 is complete after the checks below; V6-02–V6-06 remain unstarted. Changes are uncommitted on the same HEAD; no commit or push was made in this phase.

### Changed files

- Deleted `charts/featbit/templates/da-server-deployment.yaml`, `da-server-service.yaml`, `da-server-hpa.yaml` and `tests/das-test-connection.yaml` (the latter under the chart's templates directory).
- Updated `charts/featbit/values.yaml` to remove the entire `das` block and `api.olapServiceHost`.
- Updated template helpers `_helpers.tpl`, `_svc_discovery_env.tpl` and `_initContainers-wait-for-other-components.tpl` to remove DAS image/pull-secret/service references and the UI's DAS wait. Removed `OLAP__ServiceHost` from `api-deployment.yaml`.
- Updated `_postgresql-env.tpl`, `_mongodb-env.tpl`, `_pro-env.tpl` and `_otel-env.tpl` to remove DA-specific environment blocks. Retained .NET database/Redis/Kafka/telemetry configuration, `kafka-bootstrapservers`, `clickhouse-usr-pass` and the shared infrastructure wait template.
- Updated six public values examples: `examples/aks/featbit-aks-values.yaml`, `examples/pro/featbit-pro-local-pg.yaml`, and `examples/standard/{featbit-aks-via-ingress-frontdoor,featbit-hpa-deployment,featbit-standard-local-mongo,featbit-standard-local-pg}.yaml`, all under `charts/featbit/`.
- Updated root `README.md` and `charts/featbit/examples/aks/README.md` to identify the three core application services. Updated `tests/helm/postgresql-password-env.sh` to cover API/ELS only and assert absence of DA password variables.
- Updated TODO, CONTEXT and this WORKLOG. AGENTS.md, historical migration documents, private local AKS values, both skills, versions and database scripts remain unchanged.

### Helm checks

Used installed Helm `v3.13.1` and the five dependency archives already present locally; no dependency downloads, cluster access or database operations were required. Each row ran both `helm lint charts/featbit <arguments>` and `helm template v6phase charts/featbit <arguments>` and exited 0.

| Case | Arguments | Result |
| --- | --- | --- |
| Standard PostgreSQL | Defaults | Lint/template passed |
| Standard MongoDB | `--set architecture.database=mongodb --set postgresql.enabled=false --set mongodb.enabled=true` | Lint/template passed |
| Professional, bundled infrastructure | `--set architecture.tier=professional --set kafka.enabled=true --set clickhouse.enabled=true` | Lint/template passed |
| Standard api-only | `--set ui.enabled=false --set els.enabled=false` | Lint/template passed |
| Professional api-only | `--set architecture.tier=professional --set kafka.enabled=true --set clickhouse.enabled=true --set ui.enabled=false --set els.enabled=false` | Lint/template passed |
| Professional, external infrastructure / existing Secrets | Synthetic settings shown below | Lint/template passed |

The external case used these arguments for both commands. All names and endpoints are synthetic; no local private settings or real credentials were read into manifests.

```powershell
--set architecture.tier=professional
--set postgresql.enabled=false --set redis.enabled=false
--set-string externalPostgresql.hosts[0]=db.example.com:5432
--set-string externalPostgresql.username=featbit
--set-string externalPostgresql.existingSecret=postgres-test-secret
--set-string externalPostgresql.existingSecretPasswordKey=password
--set-string externalRedis.hosts[0]=cache.example.com:6379
--set-string externalRedis.existingSecret=redis-test-secret
--set-string externalRedis.existingSecretPasswordKey=password
--set-string externalKafka.brokers.producer.hosts[0]=producer.example.com:9092
--set-string externalKafka.brokers.producer.user=producer-test
--set-string externalKafka.brokers.producer.existingSecret=kafka-producer-test-secret
--set-string externalKafka.brokers.producer.existingSecretPasswordKey=password
--set-string externalKafka.brokers.producer.protocol=SASL_SSL
--set-string externalKafka.brokers.consumer.hosts[0]=consumer.example.com:9092
--set-string externalKafka.brokers.consumer.user=consumer-test
--set-string externalKafka.brokers.consumer.existingSecret=kafka-consumer-test-secret
--set-string externalKafka.brokers.consumer.existingSecretPasswordKey=password
--set-string externalKafka.brokers.consumer.protocol=SASL_SSL
--set-string externalClickhouse.host=clickhouse.example.com
--set-string externalClickhouse.user=clickhouse-test
--set-string externalClickhouse.existingSecret=clickhouse-test-secret
--set-string externalClickhouse.existingSecretKey=password
```

- Ran `helm lint charts/featbit -f <example>` and `helm template v6phase charts/featbit -f <example>` for each of the six changed public values examples listed above: all 12 commands exited 0.
- Ran `bash tests/helm/postgresql-password-env.sh` via Git Bash: all five PostgreSQL authentication cases passed (bundled default, bundled existing Secret, external inline password, external existing Secret and credentials supplied outside the chart).
- Ran an additional `helm template` with old `das.enabled=true`, `das.autoscaling.enabled=true`, `das.imagePullSecrets[0]` and `api.olapServiceHost` overrides plus distinct pull Secrets for global/UI/API/ELS/busybox/kubectl: rendering passed. Parsed output contained only the six retained pull Secrets and no retired resource or endpoint.
- Captured six baseline manifests before editing, then parsed baseline/final output with Python/PyYAML. API/ELS Deployments and all remaining application Services matched after filtering removed DA variables; UI Deployments matched after removing only the DAS wait. Verified business `DbProvider`, Standard `MqProvider=Redis`, Professional `MqProvider=Kafka`, Kafka SASL Secret references, telemetry and Professional ClickHouse wait credentials/commands.
- Parsed all 13 final manifests (six cases, six examples and the legacy-override case): no DAS resource/reference or DA-specific application environment variable remained. Api-only cases contained only the API among application components. New `OLAPProvider` / `ClickHouse__*` variables were absent, as required by the phase boundary.
- Compared parsed defaults and all six edited example values against HEAD after removing only `das` / `api.olapServiceHost`: no unrelated configuration changed.

### Residual and preservation checks

```powershell
rg -n -i '\bdas\b|\bda-server\b|data.?analytics.?server|\bda server\b|olap.?service.?host|8200' README.md charts/featbit tests .github --glob '!**/*.local.yaml' --glob '!**/*.tgz' --glob '!**/charts/**/charts/**'
rg -n 'DB_PROVIDER|POSTGRES_|MONGO_|KAFKA_(HOSTS|SECURITY_PROTOCOL|SASL_)|CHECK_DB_LIVNESS|CLICKHOUSE_(HOST|DATABASE|PORT|HTTP_PORT|SECURE|VERIFY|CLUSTER|REPLICATION|ALT_HOST|KAFKA_HOSTS)' charts/featbit/templates
git diff --check
```

- Both `rg` scans returned no matches (exit 1). `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` remain only in the retained wait-credential helper and its infrastructure wait caller; .NET Kafka callers remain in API/ELS. Historical/task references, unchanged AGENTS.md, the release skill scheduled for V6-05 and the private-file ignore rule are outside the active deployment residual check.
- Protected-file SHA256 comparison passed for 28 files, including AGENTS.md (still `a7994f1ed795d3d9fd0522ecd4d11f91285d8f71244f0eb2c768a0937d09b6cf`), all historical migrations, both initialization ConfigMaps, Chart.yaml / Chart.lock, both skills, the Redis environment helper, infrastructure waits and both private AKS values files. Private AKS files remain ignored. No private values were rendered or copied into records.
- `git diff --check` passed; reviewed the phase diff and confirmed that chart/application versions and database scripts have no changes.

### Limitations and next step

- Helm still emits the pre-existing merge warnings `skipped value for redis.architecture: Not a table` and `skipped value for postgresql.architecture: Not a table`; the matrix warning set matches the captured baseline. No new rendering warning was introduced.
- Validation is offline lint/render/configuration verification. Container startup, schema readiness, ClickHouse ingestion and end-to-end behavior were not tested. The chart still uses version `0.9.17` / App `5.4.10`; completing V6-01 does not make the full v6 upgrade deployable.
- Professional's new API ClickHouse provider configuration, treatment of legacy externalClickhouse values/helpers, initialization scripts, versions and final release documentation remain for later phases. Control Plane, SHOW_ENV_SECRETS_IN_HEADER and historical experiment conversion were not changed.
- Acceptance: no chart-generated DAS resource/dependency, no UI DAS wait, and successful remaining-component rendering. V6-01 is complete; all three saved records agree.
- Next step when authorized: V6-02, configure the Professional API's ClickHouse provider. Stop at this checkpoint for the current request; no deployment, database operation, commit or push occurred.

## 2026-10-08 · R008 · Include the private local AKS values in DA cleanup

- The user flagged `charts/featbit/examples/aks/featbit-aks-values.local.yaml`. R007 had preserved the entire file under the instruction to keep private local AKS settings. This follow-up includes its retired DA configuration in V6-01 while preserving all other private settings.
- Actual branch remains `v6`; prior V6-01 changes are uncommitted. An AGENTS.md architecture edit from four services to three was already present at the start of this follow-up. Did not edit or revert it; its SHA256 remained `d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b` throughout R008.
- Removed only the local `das` block and its heading (64 lines), preserving the file's remaining bytes, encoding and line endings. `api.olapServiceHost` and explicit `OLAP__ServiceHost` environment entries were absent. The other private AKS values file was not changed.
- Python/PyYAML compared all parsed local values before/after after removing only the former `das` key: exact equality passed. No credential, URL, Secret reference or remaining UI/API/ELS setting changed.

```powershell
helm lint charts/featbit -f charts/featbit/examples/aks/featbit-aks-values.local.yaml
helm template v6localcheck charts/featbit -f charts/featbit/examples/aks/featbit-aks-values.local.yaml
git check-ignore -q -- charts/featbit/examples/aks/featbit-aks-values.local.yaml
```

- Both Helm commands exited 0. A pre-cleanup local render using the already-cleaned chart was captured for comparison; UI/API/ELS Deployments matched the post-cleanup render. No DAS resource, DA-specific application environment variable or UI DAS wait remained. The removed local values had already been inert in the updated chart.
- Ran Helm via Python with captured output; manifests existed only in memory and were neither printed nor written to disk. No private values or connection details were copied into records.
- Git ignore verification passed. The local file remains outside tracked changes. Checksums confirmed that the existing AGENTS.md edit and the other private AKS values file remained unchanged during R008.
- Updated TODO and CONTEXT to correct the earlier whole-file preservation checkpoint. R007's chart matrix and regression results remain valid because no chart, public example or test changed in this follow-up. V6-01 remains complete; V6-02–V6-06 remain unstarted.
- Validation remains offline; runtime behavior is unverified. No deployment, database operation, version change, commit or push occurred. Next step when authorized: V6-02.

## 2026-10-09 · R009 · Deploy the current three-service chart on local Kubernetes

- The user asked whether the remaining services can run locally and authorized a deployment trial. Clarified the requested local configuration: Docker Desktop Kubernetes, not Docker Compose. The user also confirmed Kubernetes enabled in Docker Desktop.
- Restored the checkpoint and checked actual Git state: branch `v6`, HEAD `a4185bfe67898f6b4907bf8c85944d6389bb112b`; previous V6-01 changes and the existing AGENTS.md architecture edit remain uncommitted. No later upgrade phase was started.
- Ran `kubectl config use-context docker-desktop`; current context is now `docker-desktop`. Docker context was already `desktop-linux` and was not changed. Other kubeconfig contexts were preserved.
- Sandboxed cluster access failed to resolve `kubernetes.docker.internal`. Host-side commands outside the sandbox reached the local cluster and showed node `docker-desktop` Ready on Kubernetes v1.32.2. Inspected local namespaces/releases and chose a fresh namespace; existing workloads were not upgraded or removed.

### Local test configuration and installation

- Added ignored `charts/featbit/examples/standard/featbit-v6-01-smoke.local.yaml`, applied after `featbit-standard-local-pg.yaml`. It uses three ClusterIP application services, fresh bundled PostgreSQL/Redis with ephemeral storage, localhost API/ELS URLs and a JWT Secret reference. No AKS/local-private values were used.
- Lint and parsed template checks passed. Confirmed three application Deployments, the unchanged 5.4.10 images, bundled PostgreSQL/Redis, no DAS or OLAP__ServiceHost, and no PVC resources. Existing redis/postgresql.architecture merge warnings remain.
- Created namespace `featbit-v6-01-smoke` and Secret `featbit-v6-01-smoke-jwt`; Python generated a cryptographically random signing key and passed it directly to `kubectl create -f -` without printing or storing its value.

```powershell
helm lint charts/featbit -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml -f charts/featbit/examples/standard/featbit-v6-01-smoke.local.yaml
helm template featbit-v6-01-smoke charts/featbit --namespace featbit-v6-01-smoke -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml -f charts/featbit/examples/standard/featbit-v6-01-smoke.local.yaml
helm install featbit-v6-01-smoke charts/featbit --kube-context docker-desktop --namespace featbit-v6-01-smoke -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml -f charts/featbit/examples/standard/featbit-v6-01-smoke.local.yaml --wait --timeout 5m
```

- Helm install exited 0: release revision 1, status `deployed`. PostgreSQL initialized a fresh, ephemeral local test database using the unchanged chart initialization ConfigMap. No manual SQL/migration or external database operation was performed.
- Captured PostgreSQL pod logs in memory and checked only initialization/startup indicators: custom initialization scripts were detected and PostgreSQL startup completed. Raw logs were withheld; no SQL was executed for this check.
- UI/API/ELS Deployments and PostgreSQL/Redis StatefulSets are all 1/1 Ready. Five pods are Running with zero restarts. There are no PVCs in the namespace. Temporary connection-refused readiness/liveness events during initial image pull/startup cleared without pod restarts.
- Captured `helm get manifest` in memory and scanned it: no DAS resource/reference or OLAP__ServiceHost remained. No production/AKS resources or existing local releases were changed.

### HTTP verification and access

```powershell
kubectl --context docker-desktop --namespace featbit-v6-01-smoke port-forward --address 127.0.0.1 service/featbit-v6-01-smoke-ui 18081:8081
kubectl --context docker-desktop --namespace featbit-v6-01-smoke port-forward --address 127.0.0.1 service/featbit-v6-01-smoke-api 15000:5000
kubectl --context docker-desktop --namespace featbit-v6-01-smoke port-forward --address 127.0.0.1 service/featbit-v6-01-smoke-els 15100:5100
```

- All six urllib HTTP checks returned 200: UI `/` (HTML) and `/health`, API `/health/liveness` / `/health/readiness`, ELS `/health/liveness` / `/health/readiness`.
- Access: UI `http://localhost:18081/`, API `http://localhost:15000`, ELS `http://localhost:15100`. Requested opening the UI in Codex; the panel tool returned queued, so browser rendering was not separately verified.
- Loopback-only port forwards were started as hidden background helpers and left running for the user. Recorded process IDs: UI `39236`, API `27940`, ELS `63020`. Process metadata and non-secret forwarding logs are in the temporary directory `C:/Users/hu-be/AppData/Local/Temp/featbit-v6-01-portforwards-e765b11aa2524bcc81ab091715566442/`. Verify process identity before any future stop operation because IDs can be reused.

### Limits and handoff

- This establishes startup/readiness of the current 5.4.10 Standard/PostgreSQL chart after DA removal. Login, SDK evaluation, real-time updates, Insights and Professional/ClickHouse were not exercised. v6 images and required schema remain for later phases; this is not full v6 runtime verification and does not complete V6-06.
- Updated TODO and CONTEXT. V6-01 remains complete; V6-02–V6-06 remain unstarted. Existing chart changes, AGENTS.md edit and private AKS settings were preserved. No chart/version/schema edits, commit or push were made in this test.
- Current context remains `docker-desktop`. The local release and port forwards remain running for review. Next upgrade step when authorized: V6-02.
- Optional future cleanup, only when the local test is no longer needed: uninstall release `featbit-v6-01-smoke` with `--kube-context docker-desktop --namespace featbit-v6-01-smoke`, remove that dedicated namespace (including its test JWT Secret), and stop only the verified forwarding processes. No cleanup was executed in R009.

## 2026-10-09 · R010 · Verify default-account login in the local UI

- The user supplied the fresh test database's default account and requested a login trial. Used the existing Codex browser tab at `http://localhost:18081/en/login`, entered the supplied credentials and submitted Login. The password and session tokens were not copied into saved records.
- Authentication succeeded: the browser reached `http://localhost:18081/en/onboarding`, and its account menu identified the authenticated `tester`. The page displayed "Create organization and project," consistent with first-run onboarding for the fresh database.
- Left organization/project onboarding unsubmitted. The authenticated browser tab, local Helm release and loopback port forwards remain available for the user's review.
- Saved [browser screenshot evidence](C:/Users/hu-be/.codex/visualizations/2026/10/08/01a11b7e-d413-7b62-b1c7-7d6521e0a946/featbit-local-login.jpg). The screenshot shows the onboarding page and contains no password, token or SDK key.
- Updated TODO and CONTEXT with the successful login result. This follow-up changed only saved records; chart configuration, versions, database scripts, AGENTS.md and private local values were left as found. No manual database operation, commit or push was performed.
- Git remains on `v6` with the prior uncommitted changes. `git diff --check` passed, the screenshot file exists, and AGENTS.md's SHA256 still matches the R008/R009 checkpoint (`d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b`).
- Runtime evidence now includes default-account login for the unchanged 5.4.10 Standard/PostgreSQL deployment after DA removal. SDK evaluation, real-time updates, Insights, Professional/ClickHouse and actual v6 images/schema remain unverified. V6-01 remains complete; V6-02–V6-06 remain unstarted. Next upgrade step when authorized: V6-02.

## 2026-10-09 · R011 · Create a local flag and verify .NET SDK live updates

- The user requested a new feature flag, .NET SDK connectivity and a response to configuration changes. Actual Git state remains `v6` with the prior uncommitted chart changes and existing AGENTS.md edit. Restored the saved checkpoint; this is an additional local smoke test of 5.4.10, not implementation of a later upgrade phase.
- The existing authenticated UI already had organization `playground`, project `test project` (`test-project`) and current environment `Prod` (`prod`). Reused that environment and its existing server SDK key; no project, environment, key or permission was created. SDK credentials were kept out of source, saved records, logs and screenshots. The temporary key-transfer file was removed before launching the client, and the key was supplied only through the child process environment.
- Created Boolean flag `local-dotnet-sdk-smoke` named "Local .NET SDK smoke test" through the local UI. Initial state: OFF, OFF variation False, ON default rule True. Only the new local test flag's configuration was changed during this test.
- Added temporary `tests/runtime/dotnet-sdk-smoke/`: .NET 8 console project, pinned `FeatBit.ServerSdk` 2.0.1, Program.cs, README, SDK selection, local bin/obj ignore rules and sanitized runtime output. The harness subscribes to `DataChanged`, queues reevaluation outside the synchronization callback and rejects error/wrong-type evaluations. It requires valid `False -> True -> False` results and exits nonzero on failure/timeout. Event and metric collection is disabled. R012 subsequently removed the harness at the user's request; verification output is retained below.
- Used the [official server SDK documentation](https://github.com/featbit/featbit-dotnet-sdk), [NuGet package metadata](https://www.nuget.org/packages/FeatBit.ServerSdk/2.0.1) and the cached package XML documentation to verify configuration and callback APIs. No package or application image version was inferred from the chart's version number.

### Build and runtime verification

```powershell
# Run from tests/runtime/dotnet-sdk-smoke; FEATBIT_SDK_KEY is supplied privately.
$env:DOTNET_CLI_UI_LANGUAGE = 'en-US'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = 'true'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_SKIP_WORKLOAD_INTEGRITY_CHECK = '1'
$env:MSBuildEnableWorkloadResolver = 'false'
dotnet restore FeatBit.SdkSmoke.csproj --source 'C:\Users\hu-be\.nuget\packages' -p:NuGetAudit=false
dotnet build FeatBit.SdkSmoke.csproj --no-restore --configuration Release
dotnet exec .\bin\Release\net8.0\FeatBit.SdkSmoke.dll
```

- The first .NET 8 restore began an unrelated installed-workload repair. Stopped it, disabled workload resolution/integrity repair for this console-only build, and restored from the existing local NuGet cache. The subsequent restore/build exited 0 using SDK 8.0.131, with zero warnings and errors. No optional workload was needed for the test.
- Ran the client outside the sandbox to reach the existing loopback ELS port forward. At `05:51:10 UTC`, SDK initialization succeeded (`initialized=True`, `status=Ready`), and the existing flag evaluated False with `kind=Off`, while the code's fallback was True.
- Turned the flag ON in the UI. The same process received `DataChanged kind=Patch` at `05:51:42.187740 UTC` and evaluated True with `kind=Fallthrough`.
- Changed the ON default rule to False, reviewed the change and saved it with a test comment. The same process received another Patch at `05:52:17.751414 UTC` and evaluated False with `kind=Fallthrough`. Both valid results were obtained from updated SDK data without polling, manual refresh or process restart.
- The harness printed PASS for `False -> True -> False`, exited 0 and closed the SDK connection. UI-action and callback timestamps are retained in the sanitized output; they are observations, not an isolated server latency measurement or an SLA.

Sanitized runtime output retained when the temporary program was removed in R012:

```text
2026-10-09T05:51:10.6369675+00:00 CONNECT initialized=True status=Ready streaming=ws://localhost:15100
2026-10-09T05:51:10.6454316+00:00 INITIAL flag=local-dotnet-sdk-smoke value=False kind=Off reason=flag off
UI turn-ON confirmation initiated at 2026-10-09T05:51:42.047Z
2026-10-09T05:51:42.1877400+00:00 DATA_CHANGED kind=Patch
2026-10-09T05:51:42.1892285+00:00 EVALUATION value=True kind=Fallthrough reason=fall through targets and rules
CHANGE False -> True
UI default-rule save confirmation initiated at 2026-10-09T05:52:17.621Z
2026-10-09T05:52:17.7514144+00:00 DATA_CHANGED kind=Patch
2026-10-09T05:52:17.7515705+00:00 EVALUATION value=False kind=Fallthrough reason=fall through targets and rules
CHANGE True -> False
PASS: initialized from ELS and received False -> True -> False through DataChanged in one SDK process.
2026-10-09T05:52:18.2697442+00:00 CLOSED
Process exit code: 0
```

- Saved [feature flag screenshot evidence](C:/Users/hu-be/.codex/visualizations/2026/10/08/01a11b7e-d413-7b62-b1c7-7d6521e0a946/featbit-local-dotnet-sdk-smoke.jpg). Left the flag ON with default rule False and OFF variation False. The browser tab, local release and port forwards remain available; the SDK test process has stopped.
- Final checks passed: `git diff --check`, screenshot/runtime-log existence and removal of the temporary key file. Generated bin/obj files are ignored. AGENTS.md's SHA256 remains `d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b`; chart metadata and both database initialization ConfigMaps have no diff. Prior V6-01 chart changes remain uncommitted. Existing Helm checks remain valid because this follow-up changed no chart template or value.

### Limits and next step

- This verifies UI/API/Redis/ELS flag propagation and the .NET SDK callback/evaluation path for the current 5.4.10 Standard/PostgreSQL deployment after DA removal. Insights/event ingestion, Professional/ClickHouse and actual v6 images/schema were not tested. No manual SQL, migration, external database operation or historical experiment data processing was performed.
- Updated TODO and CONTEXT. V6-01 remains complete; V6-02–V6-06 remain unstarted. The runtime evidence does not complete V6-06's full v6 validation. Chart configuration, versions, initialization scripts, AGENTS.md and private AKS settings were left as found. Changes are uncommitted; no push was performed. Next upgrade step when authorized: V6-02.

## 2026-10-09 · R012 · Remove the temporary SDK program and commit V6-01

- The user authorized removing the added test program and making one local commit for the current TODO task. Reconciled actual Git state on `v6`: parent HEAD `a4185bfe67898f6b4907bf8c85944d6389bb112b`, no pre-existing staged changes, prior V6-01 implementation and records modified, AGENTS.md separately modified and the temporary SDK program untracked.
- Removed only `tests/runtime/dotnet-sdk-smoke/`, including its source, project/SDK configuration, README, transient output and generated bin/obj files. Verified the resolved target is inside this workspace and has no tracked files or reparse points before recursive deletion. The pre-existing Helm PostgreSQL regression test is retained.
- Copied the sanitized R011 runtime output into WORKLOG before deletion. Updated TODO/CONTEXT to remove stale links to the deleted program and preserve SDK connection, evaluation and live-update evidence. The local feature flag, Helm release, port forwards and screenshot evidence remain available; no runtime resource was deleted.
- Commit scope: V6-01 DA resources/configuration cleanup, remaining-component configuration preservation, current public examples/architecture documentation, the existing PostgreSQL regression-test update and the three saved upgrade records. The existing AGENTS.md edit is excluded and left in the working tree. Private AKS values and the local smoke override remain ignored and are not committed.
- This entry is included in the single local completion commit `refactor(helm): remove DA service (V6-01)`. Its parent is the SHA above; the resulting commit SHA is available from Git history, for example `git log -1 --format="%H %s" -- .codex/upgrades/featbit-v6/WORKLOG.md`. The record cannot embed its own commit hash. No push is included.
- Final review passed: `git diff --check`; active DAS reference scan returned no matches; all three private/local values files remain ignored; the temporary SDK directory is absent; Chart.yaml, Chart.lock and both database initialization ConfigMaps have no diff. AGENTS.md's SHA256 still matches `d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b`.
- Prior R007/R008 Helm lint/template, regression and preservation checks remain valid because this follow-up changed no chart source. R009–R011 runtime verification remains evidence for the unchanged 5.4.10 deployment. V6-01 stays complete; V6-02–V6-06 remain unstarted. Next upgrade step when authorized: V6-02.
