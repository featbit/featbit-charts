# FeatBit Chart v0.9.12 / App v5.4.3 Migration Guide

## Overview

This release updates FeatBit to version **5.4.3**, a maintenance release containing new features, performance improvements, security hardening, and bug fixes. It introduces **no database schema changes**, so no database migration is required. If you are upgrading from an existing deployment, ensure the **5.4.1** database migration has already been applied (see [RELEASE-v0.9.11.md](./RELEASE-v0.9.11.md)).

## Release Information

- **Chart Version**: 0.9.12 (from 0.9.11)
- **FeatBit App Version**: 5.4.3 (from 5.4.2)
- **Release Notes**:
  - https://github.com/featbit/featbit/releases/tag/5.4.3
- **Full Changelog**:
  - https://github.com/featbit/featbit/compare/5.4.2...5.4.3

## What's Changed

### FeatBit 5.4.3

- Update streaming package version ([#926](https://github.com/featbit/featbit/pull/926)).
- Dark mode initial implementation ([#919](https://github.com/featbit/featbit/pull/919)).
- Display current version in the UI ([#927](https://github.com/featbit/featbit/pull/927)).
- Allow user creation if `keyId` is unique ([#930](https://github.com/featbit/featbit/pull/930)).
- Restore project switcher modal behavior ([#931](https://github.com/featbit/featbit/pull/931)).
- Optimize rendering of the projects page ([#935](https://github.com/featbit/featbit/pull/935)).
- Consolidate SDK token authentication flow ([#928](https://github.com/featbit/featbit/pull/928)).
- Fix Redis populate race and fail fast on populate errors ([#932](https://github.com/featbit/featbit/pull/932)).
- Skip orphan index cache entries ([#933](https://github.com/featbit/featbit/pull/933)).
- Validate insights data ([#936](https://github.com/featbit/featbit/pull/936)).
- Permission checks for PATCH endpoints ([#937](https://github.com/featbit/featbit/pull/937)).
- Add SSRF protection for the webhook sender ([#938](https://github.com/featbit/featbit/pull/938)).
- Add tests for API and evaluation server ([#934](https://github.com/featbit/featbit/pull/934)).

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.4.2
- Target Version: FeatBit 5.4.3
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes

None. FeatBit **5.4.3** introduces no database schema changes and no PostgreSQL or MongoDB migration scripts. No breaking configuration or values changes are included in this chart release.

> Note: This release includes SSRF protection for the webhook sender ([#938](https://github.com/featbit/featbit/pull/938)). If your deployment relies on webhooks targeting internal/private network addresses, verify that legitimate webhook destinations are still reachable after upgrade.

---

## Upgrade Steps

### 1. Run Helm Upgrade

No database migration is required for this release.

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.12
```

### 2. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl logs -n featbit -l app.kubernetes.io/component=api --tail=50
```

## Rollback

```bash
helm rollback featbit -n featbit
```

Because this release contains no database schema changes, rolling back the Helm release to 0.9.11 requires no database changes.
