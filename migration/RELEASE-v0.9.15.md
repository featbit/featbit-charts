# FeatBit Chart v0.9.15 / App v5.4.7 Migration Guide

## Overview

This is a chart-only patch release. It keeps FeatBit and all four application image tags at
**5.4.7** and improves how PostgreSQL password environment variables are rendered.

No database schema or data migration is required.

If you are upgrading from a chart version earlier than `0.9.14`, review the intermediate
migration guides first. In particular, Cosmos DB for MongoDB deployments must complete the
index change documented in [RELEASE-v0.9.14.md](./RELEASE-v0.9.14.md).

## Release Information

- **Chart Version**: 0.9.15 (from 0.9.14)
- **FeatBit App Version**: 5.4.7 (unchanged)
- **Application Image Tags**: 5.4.7 (unchanged)

## What's Changed

- For external PostgreSQL, the chart renders `Postgres__Password` and `POSTGRES_PASSWORD` only
  when `externalPostgresql.password` or `externalPostgresql.existingSecret` is configured.
- Bundled PostgreSQL, inline external passwords, and external Kubernetes Secrets retain their
  existing behavior.
- The supported scope of the bundled Bitnami PostgreSQL dependency is documented as development
  and testing with its default authentication behavior.
- Helm linting and PostgreSQL password rendering regression tests now run before chart release.

## Migration Requirements

### Database Changes

None. This release does not change PostgreSQL or MongoDB schemas or data.

### Application and Image Changes

None. `appVersion` and the UI, API, evaluation server, and data analytics server image tags remain
at `5.4.7`.

### Configuration Impact

Existing supported credential configurations are unchanged:

- Bundled PostgreSQL continues to use the Secret provisioned by the PostgreSQL sub-chart.
- `externalPostgresql.password` continues to create and reference a chart-managed Secret.
- `externalPostgresql.existingSecret` continues to reference the configured Kubernetes Secret.
  This includes Secrets synchronized from Azure Key Vault by the Secrets Store CSI Driver.

When both external password settings are empty, the chart no longer renders a reference to a
nonexistent Secret. Such deployments must provide working PostgreSQL credentials outside this
chart; otherwise the application will not be able to connect to PostgreSQL.

### Breaking Changes

None for supported configurations.

## Upgrade Steps

Review the PostgreSQL settings in your values file, then upgrade normally:

```bash
helm repo update featbit
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --version 0.9.15 \
  -f your-values.yaml
```

## Verification

Confirm that the deployment is healthy and that PostgreSQL-backed services start successfully:

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
```

Deployments using `externalPostgresql.existingSecret` can also verify that the referenced Secret
and key exist before upgrading:

```bash
kubectl get secret <postgresql-secret-name> -n featbit
```
