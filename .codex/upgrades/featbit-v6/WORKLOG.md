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

## 2026-10-09 · R013 · Complete V6-02 Professional API ClickHouse configuration

- Invoked the resume skill and read TODO, CONTEXT, recent WORKLOG entries and AGENTS.md before checking Git. Actual branch: `v6`; HEAD: `52953b18d16d6d4cfaedca8213233d4e66ee931a` (`refactor(helm): remove DA service (V6-01)`), one commit ahead of the local `origin/v6` tracking ref. Only the pre-existing AGENTS.md edit was present; nothing was staged. This resolves R012's commit SHA without rewriting its historical entry.
- Scope is V6-02 only. The existing local smoke release, flag, port forwards and private/local settings are untouched. No cluster command, database operation, migration/script edit, later-phase implementation, version/image change, Control Plane enablement, commit or push was performed. The removed temporary .NET SDK harness remains absent; R011 evidence is retained.

### Official source verification

- Read the official FeatBit `6.0.0` sources pinned to `21b2af4feb3658a88b82349e1b31fff78ab0966c` through the GitHub connector: API provider resolver/registration, ClickHouse options/client/validation, API MQ registration/topic constants/consumer/appsettings, ELS consumer/configuration/tracking, readiness checks and ClickHouse SQL defaults. No current FeatBit main source was used.
- The supplied upgrade webpage was inaccessible through the web tool. Read the official docs source snapshot already recorded in CONTEXT (`d5cbcd9fc27f4eb24761fa19495d3f23d4178fff`, `content/docs/installation/upgrade/upgrade-to-v6.mdx`) as supplementary evidence. Verified ACL semantics with Apache Kafka's authorization reference and health-check production behavior with the pinned HealthChecks.Kafka 9.0.0 source. Evidence links are saved in CONTEXT and the Professional README.
- Confirmed that unset API OLAPProvider uses DbProvider. ClickHouse requires MqProvider=Kafka and a nonempty HTTP endpoint; options are HttpEndpoint/Database/User/Password. The client uses HTTP POST, separate Basic credentials and a database query parameter; it has no native TCP/topology/certificate-bypass options.
- With Control Plane disabled, the API still subscribes to `featbit-endusers`, `featbit-usage` and `featbit-control-plane-web-hooks`, default group `featbit-api`. The unconditionally registered web-hooks handler can process matching-region messages even while disabled. ELS subscribes to flag/segment changes with a new `evaluation-server-<GUID>` group; the command topic is conditional on enabling Control Plane. ClickHouse consumes `featbit-insights`, official SQL default group `ch_group`. Readiness produces to `healthchecks-topic` using both Kafka producer and consumer settings.
- Recorded topic READ/DESCRIBE and group READ requirements for consumers, WRITE/DESCRIBE for producers (including both configured principals on healthchecks-topic), relevant CREATE permissions for auto-creation and possible additional producer-feature ACLs. With auto-creation off, all seven documented topics must be arranged before startup. Existing bundled provisioning lists contain four; their parsed values remain unchanged. This phase documented requirements only; it did not provision topics/ACLs or verify live Kafka policy.

### Implementation and compatibility decisions

- Added `_clickhouse-env.tpl`, included only by `api-deployment.yaml`: Professional receives OLAPProvider=ClickHouse plus all four ClickHouse settings. Standard adds no OLAP override and retains its business database for v6 Insights. API/ELS MqProvider and all existing .NET PostgreSQL/MongoDB/Redis/Kafka/telemetry settings are preserved.
- Extended `_clickhouse-config.tpl` and values with bundled `clickhouse.database` and external `externalClickhouse.httpEndpoint`. Bundled endpoints match the actual Service name and HTTP port, or HTTPS Service port with TLS enabled. Configured database/user values are quoted strings. Query settings do not create/migrate any database or adapt ClickHouse SQL.
- Existing bundled/external Secret name/key takes precedence over inline password; no replacement Secret is rendered. Inline passwords use the existing generated Secret machinery and are referenced by API secretKeyRef. Empty external password without a Secret yields an empty string, including in the retained wait credential helper, rather than a missing Secret reference. Required-key diagnostics now name the correct existingSecretKey fields.
- Retained external host/httpPort/secure as a legacy endpoint fallback; explicit httpEndpoint wins. Secure selects HTTPS only for the fallback and does not convert ports. Require an absolute HTTP(S) URL with a host, optional path and no embedded credentials/query/fragment.
- Removed DAS-only tcpPort/altHosts/cluster/verify defaults and the TCP/alternate-host helper definitions after confirming they had no callers. Old supplied fields are inert. Migrate routing to an HTTP endpoint, retain actual topology in ClickHouse server configuration/tailored SQL, and use trusted certificates for HTTPS; v6 exposes no verification bypass.
- Preserved shared Kafka and ClickHouse wait callers and the bundled cluster configuration. Quoted wait usernames and Secret references, kept bundled clusterAllReplicas checks and replaced only the hardcoded HTTP wait port with the Service HTTP port. Aligned ClickHouse host/Secret naming with the subchart for empty/release-matching nameOverride. Normal default names and explicit Secret names are unchanged; those edge overrides now resolve to the actual dependency resources.
- Updated all three public Professional examples, including the external example's producer/consumer key spelling to match unchanged Kafka helpers. Added `examples/pro/README.md` and a directly related root README configuration section. They distinguish this intermediate chart from a runnable v6 upgrade, explain migration choices and record Kafka requirements without adding provisioning configuration.
- Changed chart files: `values.yaml`, `templates/_clickhouse-config.tpl`, new `templates/_clickhouse-env.tpl`, `templates/api-deployment.yaml`, `templates/_pro-env.tpl`, `templates/_initContainers-wait-for-infrastructure-dependencies.tpl`; public Professional example YAMLs; root/Professional READMEs. Added `tests/helm/clickhouse-api-env.py` and updated all three upgrade records. `clickhouse-external-secret.yaml` is reused unchanged.

### Offline verification

Copied only public chart files/dependencies to a temporary pre-change baseline; private values were not copied. The regression harness invokes Helm with synthetic values, captures manifests in memory, parses with PyYAML and prints only case summaries. Secret payload comparisons remain in memory and are not saved/printed.

```powershell
# The temporary chart was captured before V6-02 edits.
$v6BaselineChart = Get-Content -LiteralPath (Join-Path ([System.IO.Path]::GetTempPath()) 'featbit-v6-02-baseline-path.txt') -Raw
python tests/helm/clickhouse-api-env.py --baseline-chart $v6BaselineChart
& 'C:/Program Files/Git/bin/bash.exe' tests/helm/postgresql-password-env.sh
git -c core.safecrlf=false diff --check
```

- Final matrix exited 0: **24 positive cases**, **seven expected template validation rejections**, **18 pre-change deployment/service comparisons**. Positive cases cover Standard PostgreSQL/MongoDB and both API-only variants; Professional bundled/external ClickHouse, PostgreSQL/MongoDB business data, HTTP/HTTPS (including bundled TLS), default/custom databases and users, inline passwords with special characters, existing Secrets/precedence and YAML-like Secret names/keys, passwordless external use, Service/container port differences, naming overrides, legacy fallback/endpoint precedence and Professional API-only with bundled/inline/Secret credentials.
- Parsed assertions verify exact API OLAPProvider/ClickHouse values, no ClickHouse block on Standard or ELS, unchanged DbProvider/MqProvider/CacheProvider, matching wait credentials, generated Secret payloads versus synthetic input, no recreated existing Secrets, correct actual bundled Service/Secret targets and retained Kafka/ClickHouse wait logic. The 18 strict baseline comparisons preserve UI/API/ELS Deployment and Service specifications after stripping only the added API block. The six deliberately excluded strict comparisons separately test fixes to previously invalid wait username/Secret typing, missing passwordless Secret references and edge naming/ports.
- Additional parsed checks verified exact external PostgreSQL, Redis and Kafka producer/consumer Secret references on both backends and that UI/API/ELS image tags plus VERSION remain 5.4.10. All three modified public Professional examples passed Helm lint/template and API provider checks, supplying synthetic external hosts and exposure settings for the example placeholders where needed.
- The existing PostgreSQL password regression passed all five cases. Active deployment/reference checks found no DAS resources/dependency or OLAP__ServiceHost; assertion strings and historical records are not active dependencies. Removed ClickHouse helper/field lookups have no template callers.
- Two initial harness assumptions were corrected before the successful final run: YAML-like usernames intentionally change the wait value type to string, so those cases use targeted assertions rather than unchanged-baseline equality; Helm 3.13.1 lint suppresses required/fail template validation, so invalid configurations must be rejected by Helm template. Valid-case lint still passed. Existing redis.architecture/postgresql.architecture merge warnings and the informational icon recommendation remain.
- Protected hashes/parsed comparisons passed for AGENTS.md, all three ignored private/local values files, chart metadata/lock, database initialization scripts, historical releases/migrations, UI/API/ELS settings and existing .NET infrastructure values. Kafka configuration and provisioning values are unchanged. AGENTS.md retains SHA256 `d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b`; nothing was staged.

### Acceptance, limitations and next step

- V6-02 acceptance passed on 2026-10-09. Updated TODO/CONTEXT consistently: V6-01/V6-02 complete; V6-03–V6-06 unstarted. Implementation and records are uncommitted on the same HEAD; no push.
- This is Helm/source verification only. Chart/app versions remain 0.9.17/5.4.10. v6 runtime startup, schema execution, actual HTTPS trust, ClickHouse ingestion/queries and live topic/ACL behavior remain unverified. Existing R009–R011 startup/login/SDK results concern the unchanged 5.4.10 deployment and are not new v6 runtime evidence.
- Next step when separately authorized: V6-03, integrate the official schema/initialization scripts and document manual migration adapted to actual database names, Kafka authentication/address and ClickHouse layout. Do not perform historical experiment conversion, enable Control Plane or execute databases as part of this handoff.

## 2026-10-09 · R014 · Unify V6-02 ClickHouse endpoints and remove legacy fallback

- Used the featbit-v6-upgrade skill to restore TODO, CONTEXT, recent WORKLOG and AGENTS.md before checking actual Git. Branch remains `v6`; HEAD is `52953b18d16d6d4cfaedca8213233d4e66ee931a`, one commit ahead of the local origin/v6 tracking ref. Prior V6-02 implementation/records and the separate AGENTS.md edit were unstaged and preserved. Captured a public pre-follow-up chart baseline and file hashes; no private file contents or rendered Secrets were copied to the baseline/output.
- Scope is the user-requested V6-02 follow-up only. This entry is appended to the existing worklog; R013's original results and compatibility decision are retained as history. R014 supersedes the old external endpoint fallback and HTTP-only bundled wait decisions. Changes remain uncommitted and unstaged; no push.

### Implementation and compatibility

- `featbit.clickhouse.httpEndpoint` now generates the sole connection address. Bundled ClickHouse uses the unchanged dependency fullname and the HTTP/HTTPS Service port selected by TLS, including custom ports and naming overrides. Removed the separate host/httpPort helpers and replaced every caller. Fullname, database, credential/authentication and Secret helpers remain unchanged.
- External Professional configuration requires `externalClickhouse.httpEndpoint`; missing/empty values fail rendering with the field name and an explicit migration message. Removed external host/httpPort/secure defaults and all fallback logic. Old supplied/reused fields are ignored and cannot satisfy the endpoint requirement; combine their former scheme, host and actual HTTP(S) listener port into an explicit URL. TCP/altHosts/cluster/verify values/helpers were not restored. Absolute HTTP(S) validation, separated credentials and existing Secret precedence/references remain intact.
- Bundled API and API/ELS startup waits share exactly the same endpoint, scheme and Service port. The existing Professional/bundled activation conditions and clusterAllReplicas node-count query (`shards * replicaCount`) remain. Wait credentials come from the existing environment/Secret references; a separate Basic-auth header is built with quoted printf/base64 rather than URL userinfo, preserving password punctuation/newlines. HTTP still uses wget. Request exit status and quoted node-count checks prevent failed requests from satisfying startup. Kafka and other infrastructure waits are unchanged.
- Verified the configured default busybox:1.34 against pinned BusyBox 1.34.1 wget and Docker Official Image build/tag sources. Internal BusyBox TLS does not validate certificates; it can use external OpenSSL, but the examined scratch image build contains no OpenSSL/curl/CA bundle. The HTTPS branch therefore uses curl with normal chain/hostname validation, never the internal BusyBox TLS path. Missing curl exits with a clear image/trust diagnostic. `curl --disable` ignores curl configuration files; no certificate bypass or HTTP fallback is added. Default image fields/tags/repositories remain unchanged.
- Bundled TLS requires a busybox.image override with HTTPS-capable curl, trusted CAs and the existing wait utilities. The certificate must cover the generated Service hostname and be trusted in both API and wait images. No image was built/changed and no CA mount was added. Source/build and curl trust links are in CONTEXT and the Professional README. A read-only Docker image inventory could not reach the Docker Desktop engine in this execution environment; the image was not fetched/run, and Docker was not started/restarted. This establishes source/build limitations, not an executed-image or TLS-handshake result.
- Updated files in this follow-up: `charts/featbit/templates/_clickhouse-config.tpl`, `charts/featbit/templates/_initContainers-wait-for-infrastructure-dependencies.tpl`, `charts/featbit/values.yaml`, `charts/featbit/examples/pro/README.md`, root `README.md`, `tests/helm/clickhouse-api-env.py`, TODO and CONTEXT; appended this WORKLOG entry. Existing Professional example YAMLs already have endpoint/bundled settings and were validated without edits. Prior new API environment templates and Secret machinery are preserved.

### Offline verification

The temporary baseline contains public chart metadata, values, templates and dependency archives from immediately before R014. The matrix uses synthetic values, keeps manifests/Secret comparisons in memory and prints only PASS summaries. Shell checks execute only the rendered ClickHouse block against mock wget/curl functions; no network request or SQL execution occurs.

```powershell
$v6FollowupState = Get-Content -LiteralPath (Join-Path ([System.IO.Path]::GetTempPath()) 'featbit-v6-02-followup-checkpoint.json') -Raw | ConvertFrom-Json
python -u tests/helm/clickhouse-api-env.py --baseline-chart $v6FollowupState.baseline
& 'C:/Program Files/Git/bin/bash.exe' tests/helm/postgresql-password-env.sh
git -c core.safecrlf=false diff --check
```

- Matrix exited 0: **26 positive lint/template/parsed cases**, **11 expected template validation rejections**, **26 baseline comparisons**, **seven mocked startup-wait cases**. Removed two legacy fallback success cases; explicit endpoint plus old ignored fields remains a positive case. Rejections now include missing/empty endpoints and legacy-only HTTP/HTTPS values, alongside URL and Secret-key validation. Helm lint still suppresses required/fail validation, so negative acceptance uses Helm template's nonzero exit.
- Retained Standard PostgreSQL/MongoDB and API-only coverage; Professional bundled/external HTTP/HTTPS, custom databases/users, special-character inline passwords, existing Secrets/precedence, YAML-like Secret names/keys and API-only cases. Added Standard/bundled wait exclusion, bundled ClickHouse without bundled Kafka, nondefault nameOverride, distinct HTTPS Service/container ports, TLS fullnameOverride and multiple-node expectations. Parsed checks require API/wait endpoint equality and preserved Secret references, MqProvider, UI/API/ELS behavior, images and absence of active DAS/Control Plane configuration.
- Baseline normalization is limited to the final ClickHouse request/check command block; all API environment fields, wait credentials/Secret references, other infrastructure commands, initContainer settings and UI/API/ELS Deployments/Services remain compared. All 26 positive cases have a baseline comparison; no prior edge-case exclusions are needed against the R013 chart.
- Seven mocked shell checks passed: HTTP/HTTPS Basic headers with password punctuation/newlines, successful multiple-node count, HTTP/HTTPS wrong node counts, HTTP/HTTPS failed requests and absent HTTPS client. Captured arguments/status are checked privately; neither header/Secret payloads nor full manifests are printed. These checks are shell behavior evidence only, not database/TLS/runtime evidence.
- All **three existing Professional examples** passed lint/template and parsed provider/endpoint/wait checks using synthetic overrides for external placeholders and exposure, without YAML edits. The existing PostgreSQL password regression passed **five cases**. Existing redis/postgresql.architecture merge warnings remain unchanged.
- **92 protected file hashes** passed, including AGENTS.md, all three private/local files, existing examples, chart metadata/lock, schema/migration/historical files and unrelated templates. Parsed values differ only by removal of external host/httpPort/secure; all image/repository definitions, Kafka provisioning and other settings are unchanged. Retained fullname and database/user/authentication/Secret helper text is unchanged. Active DAS scan and removed-helper/fallback lookup checks passed; the temporary SDK harness remains absent. Final diff/record/Git checks are recorded below.

### Acceptance, limitations and next step

- V6-02 including this follow-up passes its offline acceptance criteria. TODO and CONTEXT record the required endpoint compatibility decision and actual new counts; R013 verification history is unchanged. V6-03–V6-06 remain unstarted. Chart/app versions remain 0.9.17/5.4.10; all image tags and bitnamilegacy repositories are unchanged.
- This does not verify v6 runtime, an actual wait-image execution, TLS handshake/certificate trust, database schema, ClickHouse ingestion/queries or live Kafka topics/ACLs. Prior FeatBit 6.0.0 source and Kafka requirements remain valid without being re-inferred from current main. R009–R011 evidence remains for the earlier 5.4.10 Standard deployment only.
- The existing local smoke deployment/flag/port forwards, private settings and AGENTS.md were not changed; no cluster command, deployment, database operation, Control Plane enablement, later phase, schema/history edit, commit or push was performed. Next step when separately authorized: V6-03 schema/initialization integration and manual migration planning.

- Final handoff checks passed: exactly nine intended follow-up files changed; all 92 other captured hashes remain unchanged. The full pre-R014 WORKLOG byte prefix is preserved. New documentation links and TODO/CONTEXT/WORKLOG counts/compatibility/status agree. `git diff --check` passes; branch/HEAD remain as restored and the index is empty. Existing prior V6-02 modifications/untracked files remain in the working tree, including the separate untouched AGENTS.md edit.


## 2026-10-10 · R015 · Track Kafka topic preparation and temporary comment cleanup

- The user requested explicit pending TODO items so the missing Kafka topic creation decision and temporary V6-02 comments are not forgotten in later phases. Used the upgrade skill to restore the relevant records/rules and actual Git state: branch `v6`, HEAD `52953b18d16d6d4cfaedca8213233d4e66ee931a`, existing implementation/AGENTS.md changes preserved. This is record maintenance only.
- Added an unchecked V6-03 task covering all seven required topics with Control Plane disabled, explicitly naming `featbit-usage`, `featbit-control-plane-web-hooks` and `healthchecks-topic`. It requires a consistent bundled provisioning/current-example/external Kafka strategy and verification of any broker/client auto-creation prerequisites and ACLs; enabled broker auto-creation alone is not accepted as proof of topic readiness.
- Added an unchecked V6-05 cleanup task naming `charts/featbit/values.yaml` and `charts/featbit/examples/pro/featbit-pro-local-pg.yaml`, their temporary V6-02 topic-list comments, and equivalent stage notes in other current examples. Cleanup follows implementation of the topic creation strategy; any remaining comments must explain permanent behavior.
- Added two unchecked V6-06 checks for topic/ACL readiness, an auto-creation-disabled development case when runtime testing is authorized, consistency with the chosen provisioning strategy, and absence of the temporary comments. Updated TODO's maintenance checkpoint/date and CONTEXT decision 18. V6-01/V6-02 completion and V6-03-V6-06 Not started status are unchanged.
- Changed only TODO, CONTEXT and this appended WORKLOG entry. Existing topic configuration/comments, chart source, AGENTS.md/private settings, runtime resources and Git state were not changed. No deployment, database operation, later-phase implementation, commit or push. Previous Helm/runtime verification history remains intact; tests were not rerun for this record-only edit. Next step is the separately authorized V6-03 work, now with explicit Kafka topic follow-up tasks.
- Verification: new tasks remain unchecked and are in their intended phases; the three records agree; prior WORKLOG bytes, all non-record file hashes and Git branch/HEAD/index are preserved; `git diff --check` passes.

## 2026-10-10 · R016 · Simplify bundled ClickHouse development startup wait

- In the side conversation, the user clarified that bundled infrastructure is for quick local debugging and explicitly approved the proposed simplification. Used the featbit-v6-upgrade skill to restore TODO, CONTEXT, recent WORKLOG and AGENTS.md, then checked actual Git: branch `v6`, HEAD `52953b18d16d6d4cfaedca8213233d4e66ee931a`, existing prior implementation/records and separate AGENTS.md edit unstaged. Captured public chart files and 102 file hashes before this change; no private values or rendered Secret payloads were copied/output.
- This entry appends to the existing history. R013/R014 verification results and R015 pending tasks are retained. R016 supersedes only R014's bundled HTTPS/curl wait support; external httpEndpoint remains required, with legacy fields inert and HTTP(S) validation unchanged.

### Implementation and compatibility

- Reduced the bundled Professional ClickHouse wait to one wget HTTP path, removing the curl capability guard and HTTPS branch. Bundled `clickhouse.tls.enabled=true` now fails Helm template with a clear HTTP-only diagnostic when the infrastructure wait is rendered, including api-only. It does not silently fall back or bypass certificate verification. The default BusyBox image, all tags and bitnamilegacy repositories remain unchanged.
- Retained the sole `featbit.clickhouse.httpEndpoint` helper for API/wait address equality, actual Service naming and custom HTTP Service ports. Authentication remains a separate Basic header from the unchanged environment/Secret references using quoted printf/base64; no credentials enter the endpoint. The original clusterAllReplicas query, shards * replicaCount check, quoted counts and request exit-status check remain. Other infrastructure waits and activation are unchanged. No address/credential/Secret helper or API environment template was edited by this simplification.
- External API HTTP/HTTPS remains supported with normal .NET certificate validation; external ClickHouse has no bundled startup wait. The previously recorded BusyBox source/build limitations explain keeping the local wait HTTP-only rather than adding a client/image/trust setup. No new source behavior was inferred from current FeatBit main.
- Updated the wait template, values comments, directly related root/Professional README text, the existing template guide paragraph and the test harness. Updated TODO/CONTEXT and appended this WORKLOG entry: nine files in this local change. Professional example YAMLs needed validation only and were not edited. No schema, migration, historical release, version/image, private setting or later-phase task was changed.

### Offline verification

The temporary pre-simplification baseline contains only public chart metadata, values, templates and dependencies. The harness uses synthetic values and compares manifests/Secrets in memory without printing their contents. Shell mocks execute only the extracted ClickHouse wait against a mock wget; no network request or SQL operation occurs.

```powershell
$v6HttpWaitState = Get-Content -LiteralPath (Join-Path ([System.IO.Path]::GetTempPath()) 'featbit-clickhouse-http-wait-checkpoint.json') -Raw | ConvertFrom-Json
python -u tests/helm/clickhouse-api-env.py --baseline-chart $v6HttpWaitState.baseline
& 'C:/Program Files/Git/bin/bash.exe' tests/helm/postgresql-password-env.sh
git -c core.safecrlf=false diff --check
```

- Matrix exited 0: **25 positive Helm lint/template/parsed cases**, **13 expected template validation rejections**, **25 pre-simplification baseline comparisons**, **four mocked wget wait cases**. Replaced bundled HTTPS success coverage with bundled TLS and TLS api-only rejection. Retained Standard PostgreSQL/MongoDB and api-only, Professional bundled/external and api-only, external HTTP/HTTPS, custom databases/users, inline special-character passwords, existing Secrets/precedence, YAML-like Secret references, passwordless external, naming overrides and distinct Service/container ports.
- Parsed checks verify exact API/wait endpoint equality, HTTP scheme/custom Service ports and node counts, unchanged Secret references and credentials, OLAP/DbProvider/MqProvider/CacheProvider mappings, UI/API/ELS settings/images and no active DAS/Control Plane dependencies. Multiple-node coverage now uses HTTP with fullnameOverride and a custom Service port. Baseline normalization was not broadened: only the intended ClickHouse request/check block and the previously normalized unused external wait credentials are excluded; all other compared configuration remains strict.
- Four mocked waits passed: special-character authentication, successful multiple-node count, wrong count and failed request. No curl branch remains; captured request arguments and credentials are not printed. These mocks verify shell flow only, not the actual BusyBox executable or a running ClickHouse server.
- All **three existing Professional examples** passed Helm lint/template and parsed provider/endpoint/wait checks with synthetic overrides, without YAML edits. The existing PostgreSQL regression passed **five cases**. Existing redis/postgresql.architecture merge warnings are unchanged.
- Parsed values match the pre-simplification chart exactly; only two related comments changed. **93 protected file hashes** passed, covering AGENTS.md, private/local files, current example YAMLs, chart metadata/lock, all helpers/API templates, schema/history and unrelated source. Active dependency and removed-helper/fallback scans found no active DAS/address compatibility callers.

### Acceptance, limitations and next step

- This simplification passes V6-02's offline acceptance criteria. TODO/CONTEXT record the actual new counts and compatibility decision without rewriting previous verification history. V6-01/V6-02 remain complete; V6-03-V6-06 and R015's Kafka/topic-comment tasks remain unstarted/unchecked.
- Chart/app versions remain 0.9.17/5.4.10. No actual wait-image execution, TLS handshake/trust, v6 runtime, ClickHouse query/ingestion, schema execution or live topic/ACL behavior was verified. Earlier startup/login/SDK results concern the unchanged 5.4.10 Standard deployment only.
- Existing smoke deployment/flag/port forwards and private settings were preserved without cluster/runtime commands. No deployment, database operation, Control Plane enablement, later-phase implementation, schema/history edit, stage, commit or push. Next step when separately authorized: V6-03 initialization/schema integration and manual migration planning, including the pending Kafka topic creation strategy.

- Final handoff checks passed: exactly nine intended files changed from the local snapshot; all 93 protected file hashes and parsed values remain unchanged. The complete pre-R016 WORKLOG byte prefix is preserved. Documentation links, record counts/compatibility/status, active dependency scan and `git diff --check` pass. Branch/HEAD are preserved and the index is empty; existing prior implementation/untracked files remain intact, including the separate unchanged AGENTS.md edit.

## 2026-10-10 · R017 · Commit V6-02 and prepare automatic V6-03 initialization

- The user authorized committing and pushing the current task and requested a next-session V6-03 prompt that includes automatic ClickHouse table creation through the Helm chart. Restored the skill, TODO/CONTEXT/WORKLOG and AGENTS.md, then checked actual Git: branch v6, HEAD `52953b18d16d6d4cfaedca8213233d4e66ee931a`, no staged files, prior V6-02/side-conversation implementation and a separate AGENTS.md edit. Verified origin points to featbit/featbit-charts and fetched origin/v6: no divergent remote commits, with only V6-01 ahead locally. The requested push includes that ancestor and this V6-02 completion.
- Commit scope: Professional API ClickHouse environment/configuration; the sole endpoint helper and required external endpoint migration; bundled HTTP-only wait with separate credentials; related public examples, root/Professional configuration documentation and TEMPLATES.md; the Helm regression harness; the three upgrade records and NEXT_SESSION_PROMPT.md. Keep AGENTS.md outside the index/commit and private/local values ignored. Versions, image tags, bitnamilegacy repositories, schema/migration/historical files and runtime resources are unchanged.
- Clarified the next phase's requirement: fresh bundled ClickHouse must automatically receive FeatBit's v6 database/tables/Kafka queue/materialized views when the chart initializes it. The user must not run SQL manually for a new local environment. Prefer the dependency's existing first-boot script mechanism after verifying actual image behavior; adapt database/Kafka targets and ordering. Existing persistent/external databases retain manual migration, with no automatic migration hook. V6-03 is not implemented in this session.
- Updated TODO/CONTEXT with that requirement and publication authorization. Saved a full English NEXT_SESSION_PROMPT.md covering PostgreSQL/MongoDB initialization, automatic bundled ClickHouse setup, seven Kafka topics, source pins, verification and exclusions. The user explicitly requested Chinese explanations; user-facing responses/next-session communication may be Chinese while source/docs/records remain English.
- Rechecked the official v6 ClickHouse SQL at `21b2af4feb3658a88b82349e1b31fff78ab0966c` and the official saved upgrade-guide source while answering initialization questions. The SQL supports initialization/manual upgrades, contains fixed featbit/kafka:9092/featbit-insights/ch_group defaults and legacy ingestion changes, and requires tailored settings/layouts where relevant. Inspected the packaged ClickHouse dependency's empty initdbScripts/defaults, Secret generation and mount at /docker-entrypoint-initdb.d; no SQL was executed and no chart initialization code was added.

### Pre-commit verification

- Current regression rerun passed: **25 positive Helm lint/template/parsed cases**, **13 expected template validation rejections**, **four mocked wget wait cases**, and **five PostgreSQL password regression cases**. The temporary R016 baseline was unavailable to the matrix's current execution environment, so this rerun made **zero new baseline comparisons**. R016's prior 25 baseline comparisons and three Professional example checks remain recorded separately; their history is not rewritten or counted as new execution. Existing redis/postgresql.architecture warnings remain.
- The harness uses synthetic settings and keeps rendered manifests/password comparisons in memory. Mock clients contact no server and execute no database query. No private values, credentials or rendered Secret payloads are printed/saved. These results do not establish v6 runtime, schema execution, ingestion, live topics/ACLs or actual wait-image/TLS behavior.
- `git diff --check` passes. All application/configuration changes are the previously reviewed V6-02 work; this publication session only edits records and adds the handoff prompt. AGENTS.md retains SHA256 `d6baac3d8e02c23264b0b56d6d25c81f3504001673b404948d38ecbeb887e29b`; private/local files remain ignored. Captured 103 file hashes and the existing WORKLOG prefix for final preservation checks without copying private contents. An earlier temporary checkpoint was not visible across sandbox calls; the final preservation checkpoint is held in tool-session memory instead.

### Commit, publication and handoff

- This entry is included in completion commit `feat(helm): configure Professional ClickHouse for v6 (V6-02)`, whose parent is the V6-01 SHA above. Resolve its SHA with Git history, for example `git log -1 --format="%H %s" --grep="configure Professional ClickHouse for v6"`. A commit cannot embed its own resulting hash; the final response reports the verified hash.
- The user explicitly authorizes a normal push of v6 to origin. Confirm the remote branch equals the new local HEAD after pushing; do not assume publication succeeded before Git confirms it. Actual Git/remote state takes precedence over earlier historical uncommitted/unpushed checkpoints.
- V6-01/V6-02 remain complete; V6-03-V6-06 remain unstarted. Next session follows NEXT_SESSION_PROMPT.md and must implement automatic initialization for fresh bundled ClickHouse along with the rest of V6-03. No deployment, database operation, smoke cleanup, Control Plane, historical experiment processing, version/image/repository change or later-phase implementation is included in this publication session.
