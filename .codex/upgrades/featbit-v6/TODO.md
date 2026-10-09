# FeatBit v6.0.0 Upgrade TODO

Last updated: 2026-10-09 (Asia/Shanghai)

## Current checkpoint

- Baseline: Chart `0.9.17` / FeatBit `5.4.10`.
- Target: FeatBit `6.0.0`; determine the target chart version in phase 4.
- Upgrade branch: `v6`, based on published chart commit `f78ba88a96eefa485517c7fb54bd2bc8395ab907`; the private local AKS setup commit is excluded from its history.
- Initial restored Git state (R007): clean `v6` at `a4185bfe67898f6b4907bf8c85944d6389bb112b`, matching the local `origin/v6` tracking ref at that checkpoint.
- R008 follow-up state: an existing AGENTS.md architecture edit was present at the start of the follow-up and was left untouched. The requested local AKS values cleanup remains ignored by Git.
- R009 runtime checkpoint: switched kubeconfig to `docker-desktop` and deployed release `featbit-v6-01-smoke` in namespace `featbit-v6-01-smoke`. All five pods are Ready with zero restarts; UI/API/ELS health endpoints returned HTTP 200. This test uses the unchanged 5.4.10 images. Deployment and localhost port forwards are left running.
- R010 login checkpoint: the user-supplied default test account authenticated successfully in the local UI and reached `/en/onboarding`. The browser displays the authenticated `tester` account and the first-run organization/project form; onboarding was not submitted.
- R011 SDK checkpoint: created `local-dotnet-sdk-smoke` in the existing `test project` / `Prod` environment. FeatBit.ServerSdk 2.0.1 on .NET 8 connected to ELS and received two `DataChanged` patches, evaluating `False -> True -> False` in one process. The client exited 0 and closed; the flag is left ON with its default rule serving False.
- R012 commit checkpoint: removed the temporary SDK program and generated files at the user's request. V6-01 implementation, current documentation/examples, the existing PostgreSQL regression test and saved records belong to the local commit `refactor(helm): remove DA service (V6-01)`, whose parent is `a4185bfe67898f6b4907bf8c85944d6389bb112b`. Resolve this commit's SHA from Git history. AGENTS.md and ignored private/local values are excluded; no push is included.
- Status: V6-01 is complete; phases V6-02–V6-06 have not started.
- Next step when authorized: V6-02, update the Professional API's ClickHouse configuration.
- Latest request: remove the added SDK test program and make one local commit for the completed V6-01 task. Preserve the recorded verification results and existing local deployment. Later upgrade phases and external database operations remain outside this request.
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
- [x] Use English only for communication, upgrade records and skill instructions.
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

- [ ] Generate `OLAPProvider=ClickHouse` and `ClickHouse__HttpEndpoint/Database/User/Password` for the API.
- [ ] Confirm that Standard uses the business database for Insights by default; preserve API/ELS `MqProvider` mapping.
- [ ] Map values for the HTTP(S) endpoint, database, user, plaintext password and existing Secret.
- [ ] Decide how to retain, remove or migrate the old `externalClickhouse` TCP, altHosts, cluster, secure and verify parameters.
- [ ] Check topics/ACLs required by the default v6 Kafka consumers; cover only requirements when Control Plane is disabled.
- [ ] Verify rendering for built-in/external ClickHouse, HTTP(S) and Secret configuration.

Acceptance: the Professional API receives complete ClickHouse configuration without depending on DAS; Standard retains the correct provider configuration.

## V6-03: Integrate v6 database initialization scripts

- [ ] Update PostgreSQL and MongoDB initialization ConfigMaps with the official v6 schema.
- [ ] Use the configured database name in initialization scripts instead of copying a fixed `featbit` target.
- [ ] Complete the Professional ClickHouse initialization/migration integration plan for the actual Kafka address, authentication and ClickHouse layout.
- [ ] Document manual migration steps for existing external databases; do not introduce a Helm hook that automatically executes migrations.
- [ ] Verify script order for new installations and the upgrade path for existing databases; record actual execution results.

Acceptance: new installations receive the schema required by v6, and the migration path for existing installations is documented. Historical experiment data conversion is outside this phase.

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
- [ ] Preserve the confirmed exclusions; do not add historical experiment conversion procedures or Control Plane deployment.

Acceptance: installation and upgrade documentation matches the final chart, and the release skill no longer requires upgrading a DAS image.

## V6-06: Validate the complete upgrade

- [ ] Run Helm lint/template for Standard PostgreSQL, Standard MongoDB, Professional and built-in/external infrastructure.
- [ ] Check non-default database names, existing Secrets, HTTP(S) endpoints and component switches.
- [ ] In a development environment, verify initialization, startup, login, evaluation with existing SDK keys and real-time updates.
- [ ] In a Professional development environment, verify ClickHouse ingestion and queries without historical experiment data conversion.
- [ ] Record verification commands, results and unverified items; review the final diff.

Acceptance: required checks pass and runtime evidence is recorded. Publishing, production deployment and actual external database operations follow the user's authorization at that time.

## Status maintenance

When a phase is complete, update this table, the checkpoint above and WORKLOG. Check off work only after its acceptance criteria pass; do not record plans or successful rendering as runtime success.

| Phase | Status | Completion date | Verification record |
| --- | --- | --- | --- |
| V6-01 | Complete | 2026-10-08 | [WORKLOG R007](WORKLOG.md) |
| V6-02 | Not started | — | — |
| V6-03 | Not started | — | — |
| V6-04 | Not started | — | — |
| V6-05 | Not started | — | — |
| V6-06 | Not started | — | — |
