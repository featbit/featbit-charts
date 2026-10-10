# FeatBit v6.0.0 Upgrade TODO

Last updated: 2026-10-10 (Asia/Shanghai)

## Current checkpoint

- R021 publication/sequence: the user authorizes committing current V6-03 work and pushing v6 to origin. This record is included in `feat(helm): integrate v6 database initialization (V6-03)`; resolve its SHA and verify the remote after publication. V6-03 runtime evidence remains pending. Insert V6-03A, a template-directory-only task, before the next upgrade work; it is queued, not implemented in this publication session.
- R020 follow-up: removed standalone INITIALIZATION.md and TEMPLATES.md per the project documentation preference. Essential initialization/manual migration usage is in the existing Professional README; active references are cleared. Targeted Helm/document checks passed; V6-03 runtime remains pending.
- R019 follow-up: removed the redundant parent clickhouse.initdbScripts empty default; the dependency already supplies it. Three targeted lint/template cases and pre/post initialization Secret/StatefulSet hash comparisons passed unchanged. V6-03 runtime remains pending.
- R018 checkpoint: verified local HEAD, origin/v6 tracking ref and actual remote at `90a11d9e2e57970e52bb8b70b510b15e691af9f7` (`feat(helm): configure Professional ClickHouse for v6 (V6-02)`). This session implements V6-03 only and performs offline checks; no deployment, SQL/broker operation, commit or push is authorized. The user reaffirmed minimal Docker Desktop trial infrastructure: keep working behavior and change only missing/broken functionality.
- Baseline: Chart `0.9.17` / FeatBit `5.4.10`.
- Target: FeatBit `6.0.0`; determine the target chart version in phase 4.
- Upgrade branch: `v6`, based on published chart commit `f78ba88a96eefa485517c7fb54bd2bc8395ab907`; the private local AKS setup commit is excluded from its history.
- Initial restored Git state (R007): clean `v6` at `a4185bfe67898f6b4907bf8c85944d6389bb112b`, matching the local `origin/v6` tracking ref at that checkpoint.
- R008 follow-up state: an existing AGENTS.md architecture edit was present at the start of the follow-up and was left untouched. The requested local AKS values cleanup remains ignored by Git.
- R009 runtime checkpoint: switched kubeconfig to `docker-desktop` and deployed release `featbit-v6-01-smoke` in namespace `featbit-v6-01-smoke`. All five pods are Ready with zero restarts; UI/API/ELS health endpoints returned HTTP 200. This test uses the unchanged 5.4.10 images. Deployment and localhost port forwards are left running.
- R010 login checkpoint: the user-supplied default test account authenticated successfully in the local UI and reached `/en/onboarding`. The browser displays the authenticated `tester` account and the first-run organization/project form; onboarding was not submitted.
- R011 SDK checkpoint: created `local-dotnet-sdk-smoke` in the existing `test project` / `Prod` environment. FeatBit.ServerSdk 2.0.1 on .NET 8 connected to ELS and received two `DataChanged` patches, evaluating `False -> True -> False` in one process. The client exited 0 and closed; the flag is left ON with its default rule serving False.
- R012 commit checkpoint: V6-01 is in commit `52953b18d16d6d4cfaedca8213233d4e66ee931a` (`refactor(helm): remove DA service (V6-01)`), whose parent is `a4185bfe67898f6b4907bf8c85944d6389bb112b`. The temporary SDK program is absent; its successful results remain in WORKLOG. AGENTS.md and private/local values are excluded. It was unpushed at R012; R017 authorizes publishing it with the V6-02 completion.
- R013 checkpoint: restored `v6` at that HEAD, one commit ahead of the local `origin/v6` tracking ref, with only the pre-existing AGENTS.md edit. V6-02 is now complete in uncommitted changes; Helm/parsed checks passed. Versions, image tags, schema/migration scripts, private settings and existing local runtime resources are preserved.
- R014 follow-up checkpoint: retained that branch/HEAD and all prior work. V6-02 now uses one ClickHouse endpoint helper for API and bundled startup wait. External `httpEndpoint` is required; host/httpPort/secure fallback is removed. HTTPS waits require curl and trusted CAs in an image override; the default BusyBox image is unchanged. Follow-up checks passed; changes remain uncommitted and unstaged.
- R016 simplification checkpoint: the user approved keeping bundled dependencies simple for local development/test. The bundled Professional wait now uses wget with HTTP only and rejects bundled TLS during rendering. The shared endpoint, separate authentication, original SQL/node count and other waits remain; external API HTTP/HTTPS is unchanged. This supersedes R014's bundled HTTPS/curl wait path. All new offline checks passed; branch/HEAD/index and prior work are preserved.
- R017 publication/handoff checkpoint: this record is included in `feat(helm): configure Professional ClickHouse for v6 (V6-02)`, with the V6-01 commit above as parent. The user authorizes committing current V6-02 work and pushing `v6` to origin, including V6-01. Resolve the completion SHA from Git history and verify actual remote state on resume; this record cannot embed its own commit hash or predict a push result. AGENTS.md remains outside the commit and private/local files remain ignored.
- Status (R021): V6-01/V6-02 complete. V6-03 implementation/offline checks are included in the authorized publication; actual initialization/startup/ingestion evidence is pending. V6-03A is queued; V6-04-V6-06 remain unstarted.
- Next step: V6-03A template organization, followed by the pending V6-03 Docker Desktop initialization/runtime checks when separately authorized. Do not begin V6-04 or change versions/images as part of the directory task.
- Prior publication request (R017): commit and push the completed current task, preserve the separate AGENTS.md edit/private settings/smoke resources, and prepare the V6-03 prompt with automatic bundled ClickHouse initialization explicitly included. This session does not implement V6-03 or execute a deployment/database operation. Metadata/images/repositories and all other exclusions remain unchanged.
- Record-maintenance follow-up (2026-10-10, WORKLOG R015): explicitly track Kafka topic creation strategy in V6-03, temporary V6-02 comment cleanup in V6-05, and verification in V6-06. These are pending tasks; this request updates records only and does not start a later phase.
- On each continuation, reconcile the saved checkpoint with the actual files, branch and Git status, then follow the user's current request.
- Context: [CONTEXT.md](CONTEXT.md); worklog: [WORKLOG.md](WORKLOG.md).
- Resume skill: [featbit-v6-upgrade](../../../.agents/skills/featbit-v6-upgrade/SKILL.md). A new session can explicitly invoke `$featbit-v6-upgrade`.

## Confirmed scope

- [x] Diagnose configuration differences between the current chart and v6.0.0.
- [x] Proceed in phases, starting with DA cleanup and validating each phase.
- [x] Exclude changes for `SHOW_ENV_SECRETS_IN_HEADER`.
- [x] Exclude enabling Control Plane, its services and optional configuration.
- [x] Exclude historical experiment data conversion, migration to the new experiment model and historical report recovery.
- [x] Keep AGENTS.md unchanged. Store this task's entry points, progress and context in .codex and the dedicated skill.
- [x] Keep source, documentation, upgrade records and skill instructions in English. The user explicitly requested Chinese explanations in R017; user-facing replies and the next session may use Chinese.
- [x] Run the user-requested local startup smoke test after V6-01 on Docker Desktop Kubernetes, using the current chart/images and isolated bundled infrastructure.
- [x] Verify the user-requested default-account login in the local UI without completing onboarding.
- [x] Create the user-requested local Boolean feature flag and verify .NET SDK initialization, valid evaluations and live configuration notifications in the current deployment.
- [x] Remove the temporary SDK program after verification; retain its results in WORKLOG and include the completed V6-01 task in one local commit.

The schema required to run v6 and chart initialization script integration remain in scope. Historical experiment data conversion uses separate scripts/programs; customers can contact FeatBit when needed.

## V6-01: Remove the DA service and all associated configuration

- [x] Delete `da-server-deployment.yaml`, `da-server-service.yaml`, `da-server-hpa.yaml` and `tests/das-test-connection.yaml`.
- [x] Remove `das.*` from `values.yaml`, along with DAS image, service, imagePullSecrets and helper references.
- [x] Remove the UI initContainer logic that waits for DAS.
- [x] Remove `api.olapServiceHost` and the API's `OLAP__ServiceHost`.
- [x] Remove Python-specific `DB_PROVIDER`, `POSTGRES_*`, `MONGO_*`, `KAFKA_*` and other DA environment variables, plus `das-pro-env` / `das-otel-env`.
- [x] Preserve .NET database, Redis and Kafka configuration, and ClickHouse wait-credential helpers used by the remaining components.
- [x] Remove DAS configuration from current deployment examples, the requested private local AKS values file and architecture documentation; retain historical release/migration documents.
- [x] Verify Standard / Professional rendering and api-only configuration with UI/ELS disabled.

Acceptance: the chart no longer generates or depends on DAS resources, the UI does not wait for DAS, and the remaining components render successfully. Rendering an intermediate phase does not establish that the complete v6 upgrade is deployable.

Acceptance passed on 2026-10-08: six configuration cases and six changed public examples passed Helm lint/template, the PostgreSQL regression test passed, parsed manifests preserved the remaining component configuration, and active DAS reference scans found no matches. R008 additionally removed the local AKS DAS block and passed lint/template with the private file, preserving all other settings. See WORKLOG R007/R008 for commands, results and limitations.

R009 on 2026-10-09 additionally verified local startup of UI/API/ELS plus PostgreSQL/Redis and six HTTP checks. R010 verified default-account login and the authenticated onboarding page. R011 verified .NET SDK evaluations and live updates for a new Boolean flag in the current 5.4.10 Standard deployment. Insights and Professional/ClickHouse remain untested; v6 runtime/schema verification remains pending. The ignored smoke override is `charts/featbit/examples/standard/featbit-v6-01-smoke.local.yaml`. R012 removed the temporary SDK harness and retained its verification output in WORKLOG R011.

## V6-02: Update Professional ClickHouse configuration

- [x] Generate `OLAPProvider=ClickHouse` and `ClickHouse__HttpEndpoint/Database/User/Password` for the API.
- [x] Confirm that Standard uses the business database for Insights by default; preserve API/ELS `MqProvider` mapping.
- [x] Map values for the HTTP(S) endpoint, database, user, plaintext password and existing Secret.
- [x] Decide how to retain, remove or migrate the old `externalClickhouse` TCP, altHosts, cluster, secure and verify parameters.
- [x] Check topics/ACLs required by the default v6 Kafka consumers; cover only requirements when Control Plane is disabled.
- [x] Verify rendering for built-in/external ClickHouse, HTTP(S) and Secret configuration.
- [x] R014: use `featbit.clickhouse.httpEndpoint` as the sole address helper; remove external host/httpPort/secure defaults and all fallback/callers of host/httpPort helpers.
- [x] R014: share the API endpoint with the bundled clusterAllReplicas startup wait; preserve activation, node counts, Secret references, separate credentials and other infrastructure waits.
- [x] R014: verify default wait-image HTTPS limitations, require a verifying curl client/trusted CAs for TLS, and pass replacement rejection tests plus retained Helm/parsed coverage.
- [x] R016: supersede the bundled HTTPS/curl wait path with HTTP-only wget for local development/test; reject bundled TLS during rendering and retain external HTTP/HTTPS API support, credentials, query/node counts and unrelated waits.

Acceptance: the Professional API receives complete ClickHouse configuration without depending on DAS; Standard retains the correct provider configuration.

Acceptance passed on 2026-10-09 (WORKLOG R013): 24 positive cases passed Helm lint/template and parsed-manifest checks, seven invalid configurations were rejected by Helm template, 18 comparisons preserved UI/API/ELS Deployments and Services apart from the new API block, three updated public examples passed, and the existing PostgreSQL regression passed. Targeted checks cover the deliberate ClickHouse wait password/Secret typing/naming/port corrections. Official source confirms Standard's OLAP fallback, Kafka mapping and default subscriptions. No v6 runtime, schema execution or live topics/ACLs were verified. See CONTEXT and the Professional example README for migration decisions; V6-03 remains unstarted.

Follow-up acceptance passed on 2026-10-09 (WORKLOG R014): 26 positive lint/template/parsed cases, 11 expected template rejections, 26 comparisons against the saved V6-02 chart and seven mocked startup-wait checks passed. Only the intended ClickHouse request/check command block is normalized in comparisons; API environment/Secrets and other waits remain compared. All three existing Professional examples and five PostgreSQL regression cases passed; their YAMLs are unchanged. Pinned BusyBox/build sources establish the default image's certificate-validation limitation; actual image execution, TLS handshakes and v6 runtime remain unverified. R014 supersedes R013's legacy fallback decision; all old external address settings must migrate to httpEndpoint.

Simplification acceptance passed on 2026-10-10 (WORKLOG R016): 25 positive lint/template/parsed cases, 13 expected template rejections, 25 comparisons against the pre-simplification chart and four mocked wget wait checks passed. Bundled TLS and bundled TLS api-only now fail with an HTTP-only diagnostic; external HTTPS cases still pass. All three existing Professional examples and five PostgreSQL regression cases passed without YAML edits. Parsed values and 93 protected file hashes are unchanged. These are offline checks, not wait-image execution, TLS-handshake or v6 runtime verification. R016 supersedes only R014's bundled HTTPS/curl wait support; required external httpEndpoint and other compatibility decisions remain.

## V6-03: Integrate v6 database initialization scripts

- [x] Update PostgreSQL and MongoDB initialization ConfigMaps with the official v6 schema.
- [x] Use the configured database name in initialization scripts instead of copying a fixed `featbit` target.
- [x] Integrate the official FeatBit ClickHouse v6 schema into the Helm chart so a fresh bundled local installation automatically creates the database, event tables, Kafka queue and materialized views without manual SQL. Prefer the dependency's existing first-boot init-script mechanism after verifying actual image behavior; keep the local HTTP setup simple and preserve custom initialization settings/order.
- [x] Complete the Professional ClickHouse initialization/migration integration plan for the actual Kafka address, authentication and ClickHouse layout.
- [x] Finalize Kafka topic creation for all seven v6-required topics with Control Plane disabled, explicitly covering `featbit-usage`, `featbit-control-plane-web-hooks` and `healthchecks-topic`. Reconcile bundled `kafka.provisioning.topics`, current Professional examples and external Kafka guidance: either provision all required topics explicitly or document and verify the broker/client auto-creation prerequisites and ACLs. Broker auto-creation being enabled alone is not proof that all topics will exist.
- [x] Document manual migration steps for existing external databases; do not introduce a Helm hook that automatically executes migrations.
- [ ] Execute and verify initialization/startup on fresh databases and the manual upgrade path on existing databases; record real SQL/topic/ingestion results. Script ordering, mounts, Bash/JavaScript syntax and mocked first-boot behavior passed offline in R018.

Acceptance: new installations receive the schema required by v6, including automatic FeatBit schema initialization for fresh bundled ClickHouse with matching database/Kafka settings and startup order. Existing persistent/external database migration remains a separate manual procedure. Historical experiment data conversion is outside this phase. Record actual execution evidence or clearly identify runtime verification still pending; manifests alone are not execution evidence.

Implementation/offline checkpoint (2026-10-10, R018): use the existing Kafka provisioning hook with seven topics and the selected ClickHouse image's first-boot `.sh` mechanism. Local default PLAINTEXT/single-node only; custom authentication/layouts use a custom init Secret or independent services. The extra topic Job, custom provisioning controls, SASL adapter, PostgreSQL guard and schema wait prototype were withdrawn after the user's simplification instruction. Existing working configuration is preserved. Actual execution remains unverified; this phase is not marked complete. R015's V6-05 cleanup audit and V6-06 live/auto-creation-disabled checks remain unchecked.

## V6-03A: Separate bundled infrastructure templates

- [ ] Create `charts/featbit/templates/builtin-infra/` for templates/helpers used exclusively by bundled development/test infrastructure.
- [ ] Move bundled PostgreSQL/MongoDB initialization ConfigMaps, the ClickHouse initialization Secret/helper and the bundled infrastructure wait helper into that directory, preserving file contents and named-template identifiers.
- [ ] Keep UI/API/ELS resources and connection/environment/Secret helpers shared by internal and external services in their current locations. Keep schema source files under `charts/featbit/files/`; do not split or optimize working helpers for this task.
- [ ] Update explicit file-path references or test selectors if needed. Verify Standard PostgreSQL/MongoDB and Professional internal/external rendering against a pre-move baseline, comparing parsed Kubernetes objects without source-path comments.

Acceptance: the bundled-only files are visibly grouped; generated Kubernetes resources, names, conditions, credentials, initialization scripts and hook behavior are unchanged. Use Helm lint/template and focused comparisons only; no new runtime deployment or standalone explanation document. This task precedes the next upgrade work and does not mark V6-03 runtime complete.

## V6-04: Update versions and images

- [ ] Determine the chart version based on final values compatibility.
- [ ] Update `Chart.yaml` appVersion and chart version.
- [ ] Update the three UI/API/ELS application images to `6.0.0`.
- [ ] Update explicitly pinned application versions in current examples; check local overrides and the effect of `--reuse-values`.
- [ ] Verify image references and version metadata.

Acceptance: the final configuration references the three v6.0.0 core images, and chart metadata is consistent.

## V6-05: Update upgrade documentation and the release skill

- [ ] Update README architecture/version information and current deployment example documentation; do not modify AGENTS.md.
- [ ] Create `migration/RELEASE-v{chart-version}.md` documenting configuration changes and manual schema migration.
- [ ] Update `.agents/skills/upgrade-featbit-chart/SKILL.md` from a four-image release workflow to the three-core-service workflow.
- [ ] Document removed values, ClickHouse configuration migration and reuse of old values.
- [ ] After the V6-03 Kafka topic creation decision is implemented, remove the temporary V6-02 topic-list comments from `charts/featbit/values.yaml` and `charts/featbit/examples/pro/featbit-pro-local-pg.yaml`, including `this list is unchanged in V6-02` / `This existing list is unchanged during V6-02`. Check other current examples for equivalent stage notes; retain only permanent comments explaining the final provisioning/auto-creation behavior.
- [ ] Preserve the confirmed exclusions; do not add historical experiment conversion procedures or Control Plane deployment.

Acceptance: installation and upgrade documentation matches the final chart, and the release skill no longer requires upgrading a DAS image.

## V6-06: Validate the complete upgrade

- [ ] Run Helm lint/template for Standard PostgreSQL, Standard MongoDB, Professional and built-in/external infrastructure.
- [ ] Check non-default database names, existing Secrets, HTTP(S) endpoints and component switches.
- [ ] In a development environment, verify initialization, startup, login, evaluation with existing SDK keys and real-time updates.
- [ ] In a Professional development environment, verify ClickHouse ingestion and queries without historical experiment data conversion.
- [ ] Verify that all seven required Kafka topics and producer/consumer/group ACLs are ready with Control Plane disabled, including an auto-creation-disabled case when development runtime testing is authorized. Check bundled provisioning manifests and current examples against the V6-03 creation strategy.
- [ ] Confirm that the temporary V6-02 Kafka topic-list comments have been removed from active values/examples and that the remaining documentation describes the final topic creation strategy.
- [ ] Record verification commands, results and unverified items; review the final diff.

Acceptance: required checks pass and runtime evidence is recorded. Publishing, production deployment and actual external database operations follow the user's authorization at that time.

## Status maintenance

When a phase is complete, update this table, the checkpoint above and WORKLOG. Check off work only after its acceptance criteria pass; do not record plans or successful rendering as runtime success.

| Phase | Status | Completion date | Verification record |
| --- | --- | --- | --- |
| V6-01 | Complete | 2026-10-08 | [WORKLOG R007](WORKLOG.md) |
| V6-02 | Complete, including follow-ups | 2026-10-10 | [WORKLOG R013/R014/R016](WORKLOG.md) |
| V6-03 | Implemented; runtime pending | — | [WORKLOG R018/R021](WORKLOG.md) |
| V6-03A | Queued next | — | [WORKLOG R021](WORKLOG.md) |
| V6-04 | Not started | — | — |
| V6-05 | Not started | — | — |
| V6-06 | Not started | — | — |
