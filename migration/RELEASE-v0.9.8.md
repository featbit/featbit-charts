# FeatBit Chart v0.9.8 / App v5.3.5 Migration Guide

## Overview

This release updates FeatBit to version **5.3.5**. It contains **no database schema changes**, but includes a **breaking change** in JWT configuration that requires action before upgrading.

## Release Information

- **Chart Version**: 0.9.8 (from 0.9.7)
- **FeatBit App Version**: 5.3.5 (from 5.3.3)
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.3.5

## What's Changed

- ✨ feat: RS256/ES256 support for JWT signing (asymmetric key algorithms)
- 🔒 security: `Jwt__Key` is now mandatory when using HS256 algorithm

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.3
- Target Version: FeatBit 5.3.5
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### ⚠️ Breaking Change: `Jwt__Key` is Now Mandatory for HS256

The `Jwt__Key` environment variable is **no longer optional** when using the default HS256 algorithm.

**Behavior:** The API service will **fail to start** if `Jwt__Key` is missing, empty, or set to the well-known placeholder value `please_change_me_to_a_secure_secret_key`.

**Action Required:** Ensure `Jwt__Key` is set to a unique, custom secret value **before upgrading**.

> **Note:** The chart now ships `Jwt__Key: "please_change_me_to_a_secure_secret_key"` and `Jwt__Algorithm: "HS256"` as defaults in `values.yaml`. This is intentionally rejected by the API to force production deployments to supply a real secret.

#### How to Check Your Current Configuration

```bash
# Check if Jwt__Key is set in your values
helm get values featbit -n featbit | grep -i jwt
```

#### How to Set `Jwt__Key` in Your Helm Values

In your `values.yaml` or override file, ensure the following is set under `api.env`:

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "HS256"
    - name: Jwt__Key
      value: "your-unique-secret-key-min-32-chars"  # replace with a real secret
    # Or load Jwt__Key from a Kubernetes secret:
    # - name: Jwt__Key
    #   valueFrom:
    #     secretKeyRef:
    #       name: featbit-secrets
    #       key: jwt-key
```

Generate a secure value with:

```bash
openssl rand -hex 32
```

> See the [JWT Configuration Documentation](https://github.com/featbit/featbit/tree/main/modules/back-end#jwt) for details on RS256/ES256 asymmetric key setup.

### Database Migration

✅ **No database migration required** — This release does not introduce any schema changes.

---

## Upgrade Steps

### 1. Verify `Jwt__Key` Is Set

Confirm your deployment has a custom `Jwt__Key` value (not the placeholder `please_change_me_to_a_secure_secret_key`) before proceeding.

### 2. Standard Upgrade

```bash
helm repo update
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.8
```

### 3. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
```

### Rollback (if needed)

```bash
helm rollback featbit -n featbit
```
