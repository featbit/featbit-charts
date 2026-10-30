# FeatBit Chart v0.9.17 / App v5.4.10 Migration Guide

## Overview

This release updates FeatBit from **5.4.9** to **5.4.10**. The upstream release changes
deployment configuration and documentation only; application code and database schemas
are unchanged from 5.4.9.

No new database migration is required. If upgrading from a chart earlier than `0.9.14`,
review the intermediate migration guides first, including the database changes in
[RELEASE-v0.9.11.md](./RELEASE-v0.9.11.md) and the Cosmos DB index requirement in
[RELEASE-v0.9.14.md](./RELEASE-v0.9.14.md). For changes introduced in 5.4.8 and 5.4.9,
see [RELEASE-v0.9.16.md](./RELEASE-v0.9.16.md).

## Release Information

- **Chart Version**: 0.9.17 (from 0.9.16)
- **FeatBit App Version**: 5.4.10 (from 5.4.9)
- **Application Image Tags**: UI, API, evaluation server, and data analytics server use `5.4.10`.
- **Release Notes**: [5.4.10](https://github.com/featbit/featbit/releases/tag/5.4.10)
- **Full Changelog**: [5.4.9...5.4.10](https://github.com/featbit/featbit/compare/5.4.9...5.4.10)

## What's Changed

- Upstream Docker Compose configurations share a `FEATBIT_VERSION` value in `.env` to pin
  application images, and the installation documentation pins the matching release.
- This chart updates `appVersion`, all four default application image tags, and the
  AKS and Front Door example image tags to `5.4.10`.

## Migration Requirements

### Database and Dependency Changes

None. This release adds no database schema or data migrations and keeps the existing
infrastructure dependency versions.

### Environment Variable and Configuration Changes

None for Helm deployments. The upstream `FEATBIT_VERSION` variable is used only for
Docker Compose interpolation; do not add it to Kubernetes service environment variables.
The chart continues to use `ui.image.tag`, `api.image.tag`, `els.image.tag`, and
`das.image.tag` to select component versions.

### Breaking Changes

None when upgrading from FeatBit 5.4.9 / Chart 0.9.16.

## Upgrade Steps

If your values files pin FeatBit image tags, update `ui.image.tag`, `api.image.tag`,
`els.image.tag`, and `das.image.tag` to `5.4.10`, including any local or backup values
files used for upgrades. `--reuse-values` alone preserves old explicit image tags.

```bash
helm repo update featbit
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --version 0.9.17 \
  -f your-values.yaml
```

## Verification

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl get deployments -n featbit \
  -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[*].image}{"\n"}{end}'
```

Confirm that enabled FeatBit components use image tag `5.4.10`, pods are healthy,
and the UI, API, and Client SDK data synchronization work as before.
