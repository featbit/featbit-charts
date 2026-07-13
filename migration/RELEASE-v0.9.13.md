# FeatBit Chart v0.9.13 / App v5.4.4 Migration Guide

## Overview

This release updates FeatBit to version **5.4.4**. It is a frontend hotfix that corrects the version reported by the UI. It introduces **no database schema changes**, so no database migration is required.

If you are upgrading from a version earlier than FeatBit 5.4.1, first review and apply the database migration documented in [RELEASE-v0.9.11.md](./RELEASE-v0.9.11.md).

## Release Information

- **Chart Version**: 0.9.13 (from 0.9.12)
- **FeatBit App Version**: 5.4.4 (from 5.4.3)
- **Release Notes**:
  - https://github.com/featbit/featbit/releases/tag/5.4.4
- **Full Changelog**:
  - https://github.com/featbit/featbit/compare/5.4.3...5.4.4

## What's Changed

### FeatBit 5.4.4

- Fix the version number displayed and logged by the frontend ([#942](https://github.com/featbit/featbit/pull/942)).
- Preserve the image version through the frontend container's runtime environment instead of reading the frontend package version.

The upstream release also rebuilt the 5.4.3 frontend image, but upgrading to 5.4.4 is the recommended path.

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.4.3
- Target Version: FeatBit 5.4.4
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Database Changes

None. FeatBit **5.4.4** contains no PostgreSQL or MongoDB schema changes or migration scripts.

### Environment Variable and Configuration Changes

None. No new chart values or user-configurable environment variables are required. Existing frontend URL and hosting settings continue to be supplied at container runtime.

### Breaking Changes

None.

---

## Upgrade Steps

### 1. Update Custom Values

If your values file pins FeatBit component image tags, update all four tags to `5.4.4`:

```yaml
ui:
  image:
    tag: 5.4.4
api:
  image:
    tag: 5.4.4
els:
  image:
    tag: 5.4.4
das:
  image:
    tag: 5.4.4
```

Do not rely on `--reuse-values` alone when upgrading: it preserves the previous release's explicit `5.4.3` image tags.

### 2. Run Helm Upgrade

No database migration is required for this release.

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --version 0.9.13 \
  -f your-values.yaml
```

### 3. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl get pods -n featbit \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
```

Confirm that the FeatBit component images use tag `5.4.4`, then open the browser console and verify that the UI reports version `5.4.4`.

## Rollback

```bash
helm rollback featbit -n featbit
```

Because this release contains no database schema changes, rolling back the Helm release to 0.9.12 requires no database changes.
