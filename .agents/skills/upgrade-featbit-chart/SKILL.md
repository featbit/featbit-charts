---
name: new-featbit-release
description: Guides creating new FeatBit releases with chart updates, version bumps, image updates, and migration handling. Use when user asks to create FeatBit release, bump FeatBit version, update chart version, or prepare new FeatBit deployment.
license: MIT
metadata:
  author: FeatBit
  version: 1.0.0
  category: release-management
---

# Create New FeatBit Release

Prepare a release of this repository's UI/API/ELS Helm chart. Read
[AGENTS.md](../../../AGENTS.md), inspect the actual branch and Git status, and
preserve unrelated changes and ignored private values. Follow the user's requested
phase: preparing or documenting a release does not authorize deployment, database
operations or publication.

## Quick checklist

- [ ] Select the chart version independently of the FeatBit application version.
- [ ] Update `version` and `appVersion` in `charts/featbit/Chart.yaml`.
- [ ] Update exactly the three core application tags: `ui.image.tag`, `api.image.tag`, `els.image.tag`.
- [ ] Synchronize explicit application tags in current public examples and version assertions in existing tests.
- [ ] Review local pins and reused values without copying private settings into public files.
- [ ] Document required schema migrations, removed/changed configuration and upstream evidence.
- [ ] Update the root README and affected existing example READMEs; preserve historical release guides.
- [ ] Run appropriate offline Helm checks and inspect rendered images, VERSION and metadata.
- [ ] Record actual runtime/migration results when testing is authorized, or leave them explicitly pending.
- [ ] Publish only within the user's authorized scope using the repository's release workflow.

## Select versions

Read actual `Chart.yaml`, `values.yaml`, Git history and the target application's
release notes before choosing versions. The current checkpoint is Chart `0.10.0`
with app/default UI/API/ELS tags `6.0.0`; future releases must use their actual target.

The chart follows SemVer independently of the application. While it remains
pre-1.0, use the repository's `0.x` convention: a minor boundary for incompatible
values changes and patches for compatible fixes/application updates as appropriate.
For example, `0.9.17 -> 0.10.0` accompanies the incompatible v6 values migration;
application major 6 does not require chart major 6. If a future chart establishes
a stable 1.x API, evaluate incompatible changes under stable SemVer rules.

`appVersion` records the FeatBit release. It is not the default image selector:
[`templates/_images.tpl`](../../../charts/featbit/templates/_images.tpl) reads each
component's `image.tag` directly. Deployment `VERSION` environment variables use
the selected tag, with `appVersion` as a fallback for that environment value only.
An empty image tag is not a reliable way to select `appVersion`.

## Update the three application images

Edit the specific fields in `charts/featbit/values.yaml`. For the current release:

```yaml
ui:
  image:
    tag: "6.0.0"
api:
  image:
    tag: "6.0.0"
els:
  image:
    tag: "6.0.0"
```

The application repositories are `featbit/featbit-ui`, `featbit/featbit-api-server`
and `featbit/featbit-evaluation-server`. Preserve registry/repository settings
unless the release requires a deliberate change; `global.imageRegistry` can override
the registry. v6 has no DAS image to update or restore.

Search from the repository root, then review field-specific diffs:

```bash
rg -n 'appVersion:|^version:' charts/featbit/Chart.yaml
rg -n 'repository:|tag:' charts/featbit/values.yaml
rg -n 'featbit/featbit-|tag:' charts/featbit/examples tests/helm

git diff -- charts/featbit/Chart.yaml charts/featbit/values.yaml charts/featbit/examples tests/helm
```

Do not globally replace every matching tag: PostgreSQL, MongoDB, Redis, Kafka,
ClickHouse, Keeper and init-container images are separate dependencies. Update
infrastructure images/versions only when required by the release's scope. Use
`helm dependency build charts/featbit` to restore missing packaged dependencies
from the lockfile; use `helm dependency update` only for an intentional dependency
change and review the resulting lockfile/archives.

Review current public examples with explicit application pins. Preserve ignored
`*.local.yaml` and backup files, and edit them only when requested. Existing
operator pins can override new defaults. Helm `--reuse-values` can retain old
coalesced chart defaults even if tags were never explicitly supplied. It can also
retain removed fields and omit new defaults. Neither `appVersion` nor updating the
three tags proves full values/schema compatibility. Explain migrating to current
defaults with a complete reviewed override file, including all desired credentials,
JWT, persistence, external URLs and other settings before using `--reset-values`.

## Write migration and configuration instructions

Create `migration/RELEASE-v{chart-version}.md` using actual upstream changes and
local implementation. The filename uses the chart version, not the application
version. Follow the existing [0.10.0 migration guide](../../../migration/RELEASE-v0.10.0.md)
for the current three-service architecture; retain older guides as historical
records.

Include the source/target chart and application versions, affected values and
environment variables, applicable incremental schema scripts, configured database
targets, upgrade commands, verification limits and recovery prerequisites. If no
schema change is required, say so with evidence. Do not invent example DDL,
backward compatibility, SDK minimum versions, migration timings or successful
execution results.

Preserve these initialization/migration distinctions:

- Fresh bundled PostgreSQL/MongoDB use ordered bootstrap/seed scripts with the
  configured database. Existing persistent/external databases need manual
  incremental migrations. Never replay the full bootstrap ConfigMap as an upgrade.
- Standalone PostgreSQL SQL can contain `\connect featbit`; adapt it to
  `externalPostgresql.database` (or the actual bundled database), even when the
  client specifies `--dbname`. Adapt MongoDB `dbName` to its configured database too.
- Professional's managed first-boot ClickHouse `.sh` path creates the local empty
  single-node schema. Existing databases and custom Kafka authentication/layouts
  need operator-owned migration/initialization. API values do not rewrite manually
  executed SQL: adapt database names, Kafka addresses/authentication, groups and
  topology. Preserve existing group offsets.
- For manually migrated bundled ClickHouse, document the managed initialization
  opt-out and persisted markers. Helm has no automatic existing-database migration
  hook. Schema updates do not perform historical experiment conversion.

For v6, remove `das.*`, `api.olapServiceHost` and custom `OLAP__ServiceHost` entries.
Professional selects `architecture.tier: professional` and configures API
`OLAPProvider=ClickHouse` / `ClickHouse__*` through chart values. External ClickHouse
requires `externalClickhouse.httpEndpoint`, database and separate credentials;
legacy host/port/TLS/topology values have no compatibility fallback. Keep existing
Secret precedence, HTTPS trust and HTTP-only bundled wait limitations documented.
Standard keeps its PostgreSQL/MongoDB provider and Redis messaging.

Keep the implemented seven-topic Kafka provisioning decision and required ACLs
consistent with the [README](../../../README.md) and release migration notes.
External Kafka preparation remains manual. Do not imply that broker auto-creation
alone guarantees all topics or that disabling Control Plane removes web-hooks.
Do not enable Control Plane or add historical data conversion as part of this release.

Update [README.md](../../../README.md) and the affected existing example READMEs,
including source-chart installation and pinned-package instructions. Confirm a
package is available before telling users to install it; pushing the `v6` branch
does not publish a chart package. Keep production external-infrastructure/external-URL
requirements and JWT configuration intact.

## Verify the release

Run offline checks from the repository root with the packaged dependencies already
present. Cover Standard PostgreSQL, Standard MongoDB and Professional, plus the
affected external-infrastructure examples using synthetic hosts and existing
Secrets. For example, these commands do not contact Kubernetes:

```bash
helm lint charts/featbit
helm lint charts/featbit -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml
helm template release-check charts/featbit -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml
helm lint charts/featbit -f charts/featbit/examples/standard/featbit-standard-local-mongo.yaml
helm template release-check charts/featbit -f charts/featbit/examples/standard/featbit-standard-local-mongo.yaml
helm lint charts/featbit -f charts/featbit/examples/pro/featbit-pro-local-pg.yaml
helm template release-check charts/featbit -f charts/featbit/examples/pro/featbit-pro-local-pg.yaml
helm show chart charts/featbit
```

Capture manifests privately; do not print real credentials. Inspect enabled
application Deployments for exactly the intended UI/API/ELS repositories/tags,
container `VERSION` values and parent chart/app metadata. Check that removed
resources/environment variables stay absent, generated connection values match
configured databases/Secrets, and initialization mounts/topic provisioning match
the documented behavior. Scan current values/examples/docs for stale release
statements; exclude historical guides and upgrade logs from removal-only scans.
Check Markdown references and `git diff --check`.

Run existing relevant regressions when implementation changes justify them:
`bash tests/helm/postgresql-password-env.sh`.
Helm lint can suppress template `required`/`fail` errors; use `helm template` to
check invalid inputs. The known all-external inline ClickHouse password/helper
render gap remains a configuration limitation: use an existing Secret for that
layout and report failures without broadening a documentation-only task.

For authorized runtime testing, use an isolated development release with valid
JWT configuration, then verify UI `/health`, API/ELS `/health/liveness` and
`/health/readiness`, login, SDK evaluation/live updates and applicable ingestion.
For fresh bundled Kafka with auto-creation disabled, omit `--wait` so the existing
post-install/post-upgrade topic hook can run, or prepare topics first. Record
actual SQL execution, restarts, manual migration and topic/ACL/query results.
Offline rendering, mocks and a healthy earlier application release do not replace
target-version runtime evidence. Leave unavailable evidence explicitly pending.

## Prepare publication

Review the final diff and report changed behavior, validation and pending evidence.
Keep private values and unrelated working changes out of release commits.
The existing [release workflow](../../../.github/workflows/release.yml) runs on
pushes to `main`, builds locked dependencies, lints, runs the PostgreSQL regression
and invokes chart-releaser. Follow that workflow when publication is authorized;
do not invent a separate index URL, main-branch push or tag convention. A local
`helm package charts/featbit` can prepare a reviewable archive when requested.

The final release review should confirm:

- Chart/app metadata and the three default image tags match the chosen versions.
- Current example pins and relevant image assertions match; infrastructure changes
  are intentional and dependencies remain locked.
- Migration/configuration instructions cite actual sources, distinguish empty
  initialization from existing-data migration and use actual database settings.
- Offline checks pass; target-version runtime/migration evidence is passed or
  clearly pending, with no claim that rendering proves execution.
- Documentation links work, historical guides remain intact and no private
  configuration or credential is included.
- Any commit, push, merge, tag, GitHub release or deployment stays within the
  user's explicit scope; record the verified outcome of authorized publication.
