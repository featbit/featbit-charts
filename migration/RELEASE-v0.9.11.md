# FeatBit Chart v0.9.11 / App v5.4.2 Migration Guide

## Overview

This release updates FeatBit through versions **5.4.1** and **5.4.2**. FeatBit **5.4.1** includes **breaking database schema changes** (new indexes and a column type widening) and must be migrated before upgrading an existing deployment. FeatBit **5.4.2** adds bug fixes and a small analytics behavior change, with no additional database migration scripts.

## Release Information

- **Chart Version**: 0.9.11 (from 0.9.10)
- **FeatBit App Version**: 5.4.2 (from 5.4.0)
- **Release Notes**:
  - https://github.com/featbit/featbit/releases/tag/5.4.1
  - https://github.com/featbit/featbit/releases/tag/5.4.2
- **Full Changelogs**:
  - https://github.com/featbit/featbit/compare/5.4.0...5.4.1
  - https://github.com/featbit/featbit/compare/5.4.1...5.4.2

## What's Changed

### FeatBit 5.4.1

- Database (PostgreSQL): new indexes on `end_users` for environment- and workspace-scoped pagination ([#915](https://github.com/featbit/featbit/pull/915)).
- Database (PostgreSQL): `pg_trgm` extension enabled and trigram GIN indexes added on `end_users.key_id` and `end_users.name` for partial/contains search.
- Database (PostgreSQL): `audit_logs.keyword` widened from `varchar(128)` to `varchar(512)` ([#917](https://github.com/featbit/featbit/pull/917)).
- Database (MongoDB): new compound indexes on `EndUsers` keyed by `envId` and `workspaceId` with `updatedAt`/`_id` for pagination ([#915](https://github.com/featbit/featbit/pull/915)).
- Evaluation: flag names or keys longer than 64 characters are evaluated correctly ([#917](https://github.com/featbit/featbit/pull/917)).

### FeatBit 5.4.2

- Fix workspace usage loading errors ([#923](https://github.com/featbit/featbit/pull/923)).
- Return null variation for archived flags ([#922](https://github.com/featbit/featbit/pull/922)).
- Fix a broken Docker Compose guide link ([#924](https://github.com/featbit/featbit/pull/924)).
- Ignore null variation insights ([#925](https://github.com/featbit/featbit/pull/925)).

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.4.0
- Target Version: FeatBit 5.4.2
- Kubernetes: >= 1.23
- Helm: >= 3.7.0
- PostgreSQL: must allow `CREATE EXTENSION pg_trgm` (superuser or appropriate grant)

### Breaking Changes

Database migration is required. Apply the correct script for your database **before** upgrading the Helm chart:

- PostgreSQL: `charts/featbit/templates/postgresql-init-scripts-configmap.yaml` -> `11_v5.4.1.sql`
- MongoDB: `charts/featbit/templates/mongodb-init-scripts-configmap.yaml` -> `10_v5.4.1.js`

The scripts are adapted from upstream FeatBit 5.4.1:

- PostgreSQL: https://github.com/featbit/featbit/blob/5.4.1/infra/postgresql/docker-entrypoint-initdb.d/v5.4.1.sql
- MongoDB: https://github.com/featbit/featbit/blob/5.4.1/infra/mongodb/docker-entrypoint-initdb.d/v5.4.1.js

FeatBit **5.4.2** does not add PostgreSQL or MongoDB migration scripts. Once the **5.4.1** migration has been applied, no extra database step is required for **5.4.2**.

Back up the database first. Index creation on large `end_users` tables can take time; consider running PostgreSQL index creation with `CONCURRENTLY` adaptations during a maintenance window if downtime must be minimized.

---

## Upgrade Steps

### 1. Apply Database Migration

For external PostgreSQL:

```bash
psql -h <host> -U <username> -d featbit -f v5.4.1.sql
```

For external MongoDB:

```bash
mongosh mongodb://<connection-string>/featbit v5.4.1.js
```

For embedded chart databases, the new init scripts are included for fresh installations. Existing embedded databases still need DBA/operator review before upgrade because Helm does not execute migrations against an already initialized database.

### 2. Run Helm Upgrade

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.11
```

### 3. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl logs -n featbit -l app.kubernetes.io/component=api --tail=50
```

PostgreSQL verification:

```sql
\d+ end_users
SELECT extname FROM pg_extension WHERE extname = 'pg_trgm';
SELECT character_maximum_length FROM information_schema.columns
 WHERE table_name = 'audit_logs' AND column_name = 'keyword';
-- expected: 512
```

MongoDB verification:

```javascript
db.EndUsers.getIndexes();
```

## Rollback

```bash
helm rollback featbit -n featbit
```

Database migrations cannot be auto-rolled back. FeatBit 5.4.2 introduces no additional database schema changes. The 5.4.1 indexes and column widening are forward-compatible with 5.4.0 (5.4.0 will tolerate the wider column and extra indexes), but if a full revert is required, drop the new indexes and narrow the column manually:

```sql
DROP INDEX IF EXISTS ix_end_users_env_id_updated_at_id;
DROP INDEX IF EXISTS ix_end_users_workspace_id_updated_at_id;
DROP INDEX IF EXISTS gin_end_users_key_id_trgm;
DROP INDEX IF EXISTS gin_end_users_name_trgm;
-- Restore narrower column only if you are certain no row exceeds 128 chars:
ALTER TABLE audit_logs ALTER COLUMN keyword TYPE character varying(128);
```

```javascript
db.EndUsers.dropIndex({envId: 1, updatedAt: -1, _id: -1});
db.EndUsers.dropIndex({workspaceId: 1, updatedAt: -1, _id: -1});
```
