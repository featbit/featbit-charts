# FeatBit Chart v0.9.5 / App v5.3.1 Migration Guide

## Overview

This release updates FeatBit to version 5.3.1 (via 5.3.0). This is a **minor release** that includes **breaking database changes** and new features.

## Release Information

- **Chart Version**: 0.9.5 (from 0.9.4)
- **FeatBit App Version**: 5.3.1 (from 5.2.4)
- **Release Notes**:
  - https://github.com/featbit/featbit/releases/tag/5.3.0
  - https://github.com/featbit/featbit/releases/tag/5.3.1

## What's Changed

### v5.3.0
- 🔐 JWT refactoring with refresh token rotation support ([#868](https://github.com/featbit/featbit/pull/868))
- 🔐 IAM permissions refactoring ([#867](https://github.com/featbit/featbit/pull/867))
- 🐛 Kafka health check fix
- 🗄️ New MongoDB indexes for sorted query fields

### v5.3.1
- ⚡ Rate limiting for evaluation server ([#874](https://github.com/featbit/featbit/pull/874))
- 🌐 Configurable CORS for evaluation server ([#877](https://github.com/featbit/featbit/pull/877))
- 🔧 SSO default tab configuration
- 🐛 Bug fixes

## Migration Requirements

### Prerequisites
- Current Version: FeatBit 5.2.x
- Target Version: FeatBit 5.3.1
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes
⚠️ **Database migration required** - This release introduces schema changes that must be applied.

### Database Changes

#### PostgreSQL

Run the following SQL against your FeatBit database **before** upgrading:

```sql
-- v5.3.0: refresh_tokens table for JWT refresh token rotation
CREATE TABLE IF NOT EXISTS refresh_tokens
(
    id                uuid                     NOT NULL DEFAULT gen_random_uuid(),
    token             character varying(500)   NOT NULL,
    user_id           uuid                     NOT NULL,
    is_revoked        boolean                  NOT NULL DEFAULT false,
    replaced_by_token character varying(500),
    created_by_ip     character varying(45),
    revoked_by_ip     character varying(45),
    expires_at        timestamp with time zone NOT NULL,
    revoked_at        timestamp with time zone,
    last_used_at      timestamp with time zone,
    created_at        timestamp with time zone NOT NULL DEFAULT now(),
    updated_at        timestamp with time zone NOT NULL,
    CONSTRAINT pk_refresh_tokens PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS ix_refresh_tokens_token ON refresh_tokens (token);
CREATE INDEX IF NOT EXISTS ix_refresh_tokens_revoked_at ON refresh_tokens (revoked_at);
```

Source: https://github.com/featbit/featbit/blob/main/infra/postgresql/docker-entrypoint-initdb.d/v5.3.0.sql

#### MongoDB

Run the following JavaScript against your FeatBit database **before** upgrading:

```javascript
// v5.3.0: new indexes for sorted query fields and RefreshTokens collection
db.Experiments.createIndex({createdAt: 1});
db.Groups.createIndex({createdAt: 1});
db.Users.createIndex({createdAt: 1});

db.RefreshTokens.createIndex({token: 1});
db.RefreshTokens.createIndex({revokedAt: 1});
```

Source: https://github.com/featbit/featbit/blob/main/infra/mongodb/docker-entrypoint-initdb.d/v5.3.0.js

> **Note**: The `v0.0.0.js` initialization script was also updated to include these indexes for fresh installations.

### Environment Variable Changes

New **optional** environment variables for the evaluation server (`els`):

| Variable | Default | Description |
|---|---|---|
| `Cors__Enabled` | `true` | Enable/disable CORS for the evaluation server |
| `Cors__AllowedOrigins` | `*` | Comma-separated allowed origins |
| `Cors__AllowedHeaders` | `*` | Comma-separated allowed headers |
| `Cors__AllowedMethods` | `*` | Comma-separated allowed methods |
| `Cors__AllowCredentials` | `false` | Allow credentials in CORS requests |
| `RateLimiting__Enabled` | `false` | Enable/disable rate limiting |

Advanced rate limiting options can be set via `els.env` in values.yaml:

| Variable | Default | Description |
|---|---|---|
| `RateLimiting__Distributed` | `false` | Use distributed rate limiting (requires Redis) |
| `RateLimiting__Type` | `FixedWindow` | Algorithm: `FixedWindow`, `SlidingWindow`, `TokenBucket`, `Concurrency` |
| `RateLimiting__PermitLimit` | `100` | Max requests per window |
| `RateLimiting__WindowSeconds` | `60` | Window duration in seconds |
| `RateLimiting__Endpoints__Insight__PermitLimit` | `200` | Per-endpoint override for insight endpoint |

### Configuration Changes

New optional configuration in `values.yaml` under the `els` section:

```yaml
els:
  cors:
    enabled: true
    allowedOrigins: "*"
    allowedHeaders: "*"
    allowedMethods: "*"
    allowCredentials: false

  rateLimiting:
    enabled: false
```

## Upgrade Instructions

### Standard Upgrade Process

1. **Run database migration scripts** (see Database Changes above)

2. **Update your values file** (if using custom values):
   ```yaml
   # Optional: configure CORS and rate limiting for evaluation server
   els:
     cors:
       enabled: true
       allowedOrigins: "https://your-app.com"
     rateLimiting:
       enabled: false
   ```

3. **Update Helm repository**:
   ```bash
   helm repo update
   ```

4. **Upgrade the release**:
   ```bash
   helm upgrade featbit featbit/featbit \
     --version 0.9.5 \
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
  --version 0.9.5 \
  --namespace featbit \
  --values featbit-aks-values.local.yaml
```

### Verification

After upgrading, verify:

```bash
# Check all pods are running
kubectl get pods -n featbit

# Check the new version
helm list -n featbit

# Verify evaluation server health
kubectl exec -it deploy/featbit-els -n featbit -- curl -s http://localhost:5100/health/liveness
```

## Rollback

If issues occur, rollback to the previous version:

```bash
helm rollback featbit -n featbit
```

> **Note**: If you already ran the database migration scripts, the rollback will not revert the database changes. The new `refresh_tokens` table and indexes are backward-compatible and will not affect the previous version.
