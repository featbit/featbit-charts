# FeatBit Chart v0.9.10 / App v5.4.0 Migration Guide

## Overview

This release updates FeatBit to version **5.4.0**. It includes **breaking database schema changes** and must be migrated before upgrading an existing deployment.

## Release Information

- **Chart Version**: 0.9.10 (from 0.9.9)
- **FeatBit App Version**: 5.4.0 (from 5.3.6)
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.4.0

## What's Changed

- Database: environment `settings` are normalized to a JSON object.
- Database: workspace membership is extracted from `users` into the new `workspace_users` table/collection.
- Database: duplicate users are collapsed by email, with dependent records repointed to the canonical user.
- Database: `workspace_id` is removed from users and user email becomes globally unique.
- Database: `initial_password` moves from organization membership records to users.

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.6
- Target Version: FeatBit 5.4.0
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes

Database migration is required. Apply the correct script for your database **before** upgrading the Helm chart:

- PostgreSQL: `charts/featbit/templates/postgresql-init-scripts-configmap.yaml` -> `10_v5.4.0.sql`
- MongoDB: `charts/featbit/templates/mongodb-init-scripts-configmap.yaml` -> `09_v5.4.0.js`

The scripts are adapted from upstream FeatBit 5.4.0:

- PostgreSQL: https://github.com/featbit/featbit/blob/5.4.0/infra/postgresql/docker-entrypoint-initdb.d/v5.4.0.sql
- MongoDB: https://github.com/featbit/featbit/blob/5.4.0/infra/mongodb/docker-entrypoint-initdb.d/v5.4.0.js

Back up the database first. These migrations rewrite user references and remove columns/fields; they are not automatically reversible by `helm rollback`.

---

## Upgrade Steps

### 1. Apply Database Migration

For external PostgreSQL:

```bash
psql -h <host> -U <username> -d featbit -f v5.4.0.sql
```

For external MongoDB:

```bash
mongosh mongodb://<connection-string>/featbit v5.4.0.js
```

For embedded chart databases, the new init scripts are included for fresh installations. Existing embedded databases still need DBA/operator review before upgrade because Helm does not execute migrations against an already initialized database.

### 2. Run Helm Upgrade

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.10
```

### 3. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl logs -n featbit -l app.kubernetes.io/component=api --tail=50
```

## Rollback

```bash
helm rollback featbit -n featbit
```

Database migrations cannot be auto-rolled back. Restore from a verified backup if the database state must be reverted.
