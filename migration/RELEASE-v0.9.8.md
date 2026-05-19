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
- 📋 chart: `Jwt__Algorithm` and `Jwt__Key` are now explicit fields in `api.env` in `values.yaml`

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.3
- Target Version: FeatBit 5.3.5
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### ⚠️ Breaking Change: JWT Configuration is Now Mandatory

Starting from v5.3.4, the API **requires explicit JWT configuration** at startup. The required fields depend on which algorithm (`Jwt__Algorithm`) you use.

#### Algorithm Quick Reference

| `Jwt__Algorithm` | Required fields | Key type |
|---|---|---|
| `HS256` (default) | `Jwt__Key` | Shared symmetric secret |
| `RS256` | `Jwt__PrivateKeyPath`, `Jwt__PublicKeyPath` | RSA key pair (PEM files) |
| `ES256` | `Jwt__PrivateKeyPath`, `Jwt__PublicKeyPath` | EC key pair (PEM files) |

---

#### Option A — HS256 (Symmetric, default)

The `Jwt__Key` environment variable is **no longer optional**.

**Behavior:** The API will **fail to start** if `Jwt__Key` is missing, empty, or set to the well-known placeholder `please_change_me_to_a_secure_secret_key`.

> **Note:** The chart ships `Jwt__Key: "please_change_me_to_a_secure_secret_key"` as a default in `values.yaml`. This is intentionally rejected by the API to force production deployments to supply a real secret.

Generate a secure key:

```bash
openssl rand -hex 32
```

Set it in your override file under `api.env`:

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "HS256"
    - name: Jwt__Key
      value: "your-64-char-random-secret"        # plain value (dev/test only)
    # Preferred for production — load from a Kubernetes secret:
    # - name: Jwt__Key
    #   valueFrom:
    #     secretKeyRef:
    #       name: featbit-jwt-secret
    #       key: jwt-key
```

---

#### Option B — RS256 / ES256 (Asymmetric, recommended for production / compliance)

Use `RS256` or `ES256` if your security policy requires asymmetric signing (e.g. SOC 2, ISO 27001, or environments where the public key must be shared with external verifiers without exposing the signing secret).

**Generate key pairs:**

```bash
# RS256
openssl genrsa -out jwt-rs-private.pem 2048
openssl rsa -in jwt-rs-private.pem -pubout -out jwt-rs-public.pem

# ES256
openssl ecparam -name prime256v1 -genkey -noout -out jwt-es-private.pem
openssl ec -in jwt-es-private.pem -pubout -out jwt-es-public.pem
```

**Store the PEM files as a Kubernetes secret:**

```bash
kubectl create secret generic featbit-jwt-keypair \
  --from-file=private.pem=./jwt-rs-private.pem \
  --from-file=public.pem=./jwt-rs-public.pem \
  -n featbit
```

**Mount the secret and configure paths in your override file:**

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "RS256"                    # or ES256
    - name: Jwt__PrivateKeyPath
      value: "/mnt/jwt-keys/private.pem"
    - name: Jwt__PublicKeyPath
      value: "/mnt/jwt-keys/public.pem"

  volumeMounts:
    - name: jwt-keys
      mountPath: "/mnt/jwt-keys"
      readOnly: true

  volumes:
    - name: jwt-keys
      secret:
        secretName: featbit-jwt-keypair
```

> When using RS256/ES256, `Jwt__Key` is ignored. Do **not** set it.

---

#### How to Check Your Current Configuration

```bash
helm get values featbit -n featbit | grep -i jwt
```

> 📖 **Reference:** [JWT Configuration Documentation](https://github.com/featbit/featbit/tree/main/modules/back-end#jwt) — full list of `Jwt__*` environment variables, algorithm details, and key requirements.

### Database Migration

✅ **No database migration required** — This release does not introduce any schema changes.

---

## Upgrade Steps

### 1. Pre-upgrade Check

```bash
# Check your current JWT configuration
helm get values featbit -n featbit | grep -i jwt
```

Choose the path below based on your situation.

---

### Path A — HS256 (symmetric, most common)

**A1. If `Jwt__Key` is already set to a custom value in your override file**, skip to Step 2.

**A2. If `Jwt__Key` is missing or still set to the placeholder**, add it to your override values file before upgrading:

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "HS256"
    - name: Jwt__Key
      value: "your-64-char-random-secret"   # generate with: openssl rand -hex 32
    # Or from a Kubernetes secret:
    # - name: Jwt__Key
    #   valueFrom:
    #     secretKeyRef:
    #       name: featbit-jwt-secret
    #       key: jwt-key
```

---

### Path B — RS256 / ES256 (asymmetric, for compliance environments)

**B1. Generate a key pair** (if you don't have one already):

```bash
# RS256
openssl genrsa -out jwt-rs-private.pem 2048
openssl rsa -in jwt-rs-private.pem -pubout -out jwt-rs-public.pem

# ES256
openssl ecparam -name prime256v1 -genkey -noout -out jwt-es-private.pem
openssl ec -in jwt-es-private.pem -pubout -out jwt-es-public.pem
```

**B2. Store the PEM files as a Kubernetes secret:**

```bash
kubectl create secret generic featbit-jwt-keypair \
  --from-file=private.pem=./jwt-rs-private.pem \
  --from-file=public.pem=./jwt-rs-public.pem \
  -n featbit
```

**B3. Add the following to your override values file:**

```yaml
api:
  env:
    - name: Jwt__Algorithm
      value: "RS256"                      # or ES256
    - name: Jwt__PrivateKeyPath
      value: "/mnt/jwt-keys/private.pem"
    - name: Jwt__PublicKeyPath
      value: "/mnt/jwt-keys/public.pem"

  volumeMounts:
    - name: jwt-keys
      mountPath: "/mnt/jwt-keys"
      readOnly: true

  volumes:
    - name: jwt-keys
      secret:
        secretName: featbit-jwt-keypair
```

---

### 2. Run Helm Upgrade

```bash
helm repo update

# With an override values file (recommended):
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --values your-override-values.yaml \
  --version 0.9.8

# Or reuse existing values if JWT is already configured correctly:
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --reuse-values \
  --version 0.9.8
```

### 3. Verify Upgrade

```bash
kubectl get pods -n featbit
helm history featbit -n featbit

# Confirm the API pod started successfully (no JWT errors in logs)
kubectl logs -n featbit -l app.kubernetes.io/component=api --tail=50
```

### Rollback (if needed)

```bash
helm rollback featbit -n featbit
```
