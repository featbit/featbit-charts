# FeatBit Chart v0.9.9 / App v5.3.6 Migration Guide

## Overview

This release updates FeatBit to version **5.3.6**. It contains **no database schema changes** and can be upgraded without running migration scripts.

## Release Information

- **Chart Version**: 0.9.9 (from 0.9.8)
- **FeatBit App Version**: 5.3.6 (from 5.3.5)
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.3.6

## What's Changed

- Infra: upgraded API and evaluation server runtime to .NET 10.
- Infra: upgraded CI workflow actions and .NET versions.
- Feature: added support and documentation links.
- Feature: verify permissions when accessing workspace via OpenAPI.
- Fix: corrected yearly plan fee breakdown display.
- UI: user experience improvements.

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.5
- Target Version: FeatBit 5.3.6
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes

No database migration is required. This release does not introduce database schema changes.

If you upgraded from a version earlier than v5.3.5, review the previous migration guides first, especially `migration/RELEASE-v0.9.8.md` for JWT configuration requirements.

---

## Upgrade Steps

### Standard Upgrade

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.9
```

### Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
```
