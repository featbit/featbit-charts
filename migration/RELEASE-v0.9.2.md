# FeatBit Chart v0.9.2 / App v5.2.2 Migration Guide

## Overview

This release updates FeatBit to version 5.2.2. This is a **patch release** with bug fixes and feature enhancements that require **no migration steps**.

## Release Information

- **Chart Version**: 0.9.2 (from 0.9.1)
- **FeatBit App Version**: 5.2.2 (from 5.2.1)
- **Release Date**: February 6, 2026
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.2.2

## What's Changed

### Bug Fixes
- 🐛 Fix: segment updates not reflected on client-side clients in certain scenarios
- 🐛 Fix: user can bypass flag IAM permissions

### New Features
- ✨ Feat: flag concurrent edits detection
- ✨ Feat: flag evaluation API
- ✨ Feat: added new endpoints to open api
- 📖 Doc: complement open api docs

## Migration Requirements

### Prerequisites
- Current Version: FeatBit 5.2.x
- Target Version: FeatBit 5.2.2
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes
❌ **None** - This is a backward-compatible patch release.

### Database Changes
✅ **No database migration required** - No schema changes in this release.

### Environment Variable Changes
✅ **No environment variable changes** - All existing configurations remain valid.

### Configuration Changes
✅ **No configuration changes required** - Existing values.yaml configurations are fully compatible.

## Upgrade Instructions

### Standard Upgrade Process

1. **Update your values file** (if using custom values):
   ```bash
   # No changes needed for this release
   # Your existing values.yaml remains compatible
   ```

2. **Update Helm repository**:
   ```bash
   helm repo update
   ```

3. **Upgrade the release**:
   ```bash
   helm upgrade featbit featbit/featbit \
     --version 0.9.2 \
     --namespace featbit \
     --values your-values.yaml
   ```

### AKS Deployment

For Azure Kubernetes Service deployments:

```bash
cd charts/featbit/examples/aks

# Update Helm repo
helm repo update

# Upgrade FeatBit
helm upgrade featbit featbit/featbit \
  --version 0.9.2 \
  --namespace featbit \
  --values featbit-aks-values.local.yaml
```

### Verification

After upgrading, verify the deployment:

```bash
# Check pod status
kubectl get pods -n featbit

# Check service versions
kubectl describe deployment -n featbit | grep Image:

# Expected output should show version 5.2.2 for all components:
# - featbit/featbit-ui:5.2.2
# - featbit/featbit-api-server:5.2.2
# - featbit/featbit-evaluation-server:5.2.2
# - featbit/featbit-data-analytics-server:5.2.2
```

## Rollback Instructions

If you need to rollback to the previous version:

```bash
helm rollback featbit -n featbit
```

Or explicitly rollback to chart version 0.9.1:

```bash
helm upgrade featbit featbit/featbit \
  --version 0.9.1 \
  --namespace featbit \
  --values your-values.yaml
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/featbit/featbit/issues
- Documentation: https://docs.featbit.co
- Full Changelog: https://github.com/featbit/featbit/compare/5.2.1...5.2.2

## Summary

✅ **Simple upgrade** - No migration steps required  
✅ **No downtime needed** - Rolling update supported  
✅ **Backward compatible** - All existing configurations work  
✅ **No database changes** - Direct upgrade without schema migration  

This is a straightforward patch release that can be upgraded with a standard Helm upgrade command.
