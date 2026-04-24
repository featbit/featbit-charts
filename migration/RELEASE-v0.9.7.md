# FeatBit Chart v0.9.7 / App v5.3.3 Migration Guide

## Overview

This release updates FeatBit to version **5.3.3**. It contains **no database schema changes** — upgrade can be performed without any migration scripts.

## Release Information

- **Chart Version**: 0.9.7 (from 0.9.6)
- **FeatBit App Version**: 5.3.3 (from 5.3.2)
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.3.3

## What's Changed

- 🐛 fix: organization & project router links ([#892](https://github.com/featbit/featbit/pull/892))
- ✨ feat: OpenApis for updating feature flag/segment targeting ([#893](https://github.com/featbit/featbit/pull/893))

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.2
- Target Version: FeatBit 5.3.3
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes

✅ **No database migration required** — This release does not introduce any schema changes.

---

## Upgrade Steps

### Standard Upgrade

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.7
```

### Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
```
