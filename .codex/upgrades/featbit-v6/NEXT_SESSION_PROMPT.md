$featbit-v6-upgrade

Work in `C:\Code\featbit\featbit-charts` on branch `v6`. Communicate with the user
in Chinese; keep source, documentation and upgrade records in English.

Restore TODO, CONTEXT and recent WORKLOG through the skill, read AGENTS.md and
inspect the actual Git branch, HEAD, working tree and remote state. Preserve all
existing work, the separate AGENTS.md edit, ignored private AKS/local settings and
the existing smoke deployment, feature flag and port forwards.

Implement V6-03 only. Do not begin V6-04 or later.

Checkpoint:

- V6-01 and V6-02 are complete. The previous session was asked to commit/push the
  current work; verify actual Git rather than assuming publication succeeded.
- Chart/app versions remain 0.9.17 / 5.4.10; image tags and bitnamilegacy repositories
  are unchanged. Rendering is not evidence of a working v6 deployment.
- Professional API ClickHouse configuration is implemented. External ClickHouse
  requires httpEndpoint; old host/httpPort/secure/TCP/topology fallback is removed.
- Bundled ClickHouse is for quick local Kubernetes debugging: retain the simple
  HTTP-only wget wait, shared endpoint and separate Secret-backed credentials.
  External API HTTP/HTTPS remains supported. Preserve unrelated UI/API/ELS and
  PostgreSQL/MongoDB/Redis/Kafka configuration and absence of DAS.

Requirements:

1. Update bundled PostgreSQL and MongoDB initialization ConfigMaps to the official
   v6 schema. Use the configured database names and verify initialization ordering.
2. Make fresh bundled ClickHouse installations initialize FeatBit automatically
   through the Helm chart. The user must not need to run SQL manually for a new
   local environment. Integrate the official v6 ClickHouse SQL so the database,
   experiment event tables, Kafka queue and materialized views are created.
   Prefer the dependency's existing initdbScripts / first-boot mount mechanism
   after verifying the selected image's actual behavior. Keep the implementation
   simple; preserve user initialization settings and document precedence/order.
3. Adapt ClickHouse SQL to the configured database and actual generated Kafka
   Service/broker address, authentication and supported layout. API environment
   variables do not rewrite SQL. Verify initialization, topic preparation and
   readiness ordering; avoid dependency/hook deadlocks. Do not broaden bundled
   infrastructure into production cluster/TLS management.
4. Resolve the Kafka topic creation strategy with Control Plane disabled. Cover
   all seven required topics: featbit-feature-flag-change, featbit-segment-change,
   featbit-endusers, featbit-insights, featbit-usage,
   featbit-control-plane-web-hooks and healthchecks-topic. Reconcile bundled
   provisioning, current examples and external guidance. Do not assume enabled
   broker auto-creation alone guarantees topic existence; verify client/group ACL
   and creation prerequisites against the pinned sources.
5. Document the manual migration procedure for existing persistent/external
   databases. Automatic first-boot initialization must not become automatic
   migration of existing databases on helm upgrade. Preserve historical release
   documents and do not add a migration hook for existing data.
6. Update directly related current values, examples, templates and configuration
   documentation. Keep R015's later documentation-cleanup tasks tracked; do not
   start the general V6-05 release-documentation phase.

Use official FeatBit 6.0.0 sources pinned to
`21b2af4feb3658a88b82349e1b31fff78ab0966c` and the official documentation evidence
in CONTEXT. The ClickHouse source is
`infra/clickhouse/docker-entrypoint-initdb.d/v6.0.0.sql`. Verify unresolved details
against those sources and the packaged dependencies/image sources, not current
FeatBit main.

Run appropriate Helm lint/template and parsed-manifest checks for Standard
PostgreSQL/MongoDB, Professional bundled/external ClickHouse and api-only setups.
Check generated initialization resources/mounts, custom database names, actual
Kafka Service naming/ports, inline passwords/existing Secrets, component switches,
external infrastructure exclusions, preserved application settings and no DAS.
Test initialization ordering and script syntax as far as offline checks allow.
Record actual counts, failures and limitations; rendered SQL is not proof it ran.

Do not deploy, execute SQL or other database operations, modify the smoke resources,
commit or push in this session unless separately authorized. Do not change chart/app
versions, image tags or bitnamilegacy repositories; enable Control Plane; restore
DAS; handle SHOW_ENV_SECRETS_IN_HEADER; process historical experiment data; or
modify historical release/migration documents. Keep credentials and rendered
Secret values out of output and records.

Update TODO, CONTEXT and WORKLOG with implementation, compatibility decisions,
verification and pending runtime evidence. Mark V6-03 complete only if its
acceptance criteria pass; clearly record any execution verification that remains
pending. Finish with a concise implementation and verification summary in Chinese.
