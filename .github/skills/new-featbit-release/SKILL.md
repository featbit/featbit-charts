---
name: new-featbit-release
description: Guides creating new FeatBit releases with chart updates, version bumps, image updates, and migration handling. Use when user asks to create FeatBit release, bump FeatBit version, update chart version, or prepare new FeatBit deployment.
license: MIT
metadata:
  author: FeatBit
  version: 1.0.0
  category: release-management
---

# Create New FeatBit Release

Complete workflow for creating a new FeatBit release, including chart updates, version bumps, image updates, and migration handling.

## Quick Checklist

- [ ] Update FeatBit application version (appVersion in Chart.yaml)
- [ ] Update Helm chart version (version in Chart.yaml)
- [ ] Update all image tags in values.yaml (ui, api, els, da-server)
- [ ] Create/update database migration file (if needed)
- [ ] Document environment variable changes
- [ ] Document breaking changes
- [ ] Update chart dependencies (if needed)
- [ ] Test locally before publishing

## Release Workflow Overview

```
1. Version Planning → 2. Update Chart Files → 3. Create Migration
     ↓                        ↓                      ↓
4. Test Locally → 5. Document Changes → 6. Publish Release
```

## Step 1: Version Planning

Determine version numbers following semantic versioning:

**Chart Version** (`version` in Chart.yaml):
- Follows Semantic Versioning (SemVer): MAJOR.MINOR.PATCH
- **MAJOR**: Breaking changes, incompatible API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

**App Version** (`appVersion` in Chart.yaml):
- FeatBit application version (e.g., "5.2.1", "5.3.0")
- Matches FeatBit core release version
- Used as default image tag

**Examples:**
```
Chart 0.9.1 → 0.9.2 (patch: bug fix in chart templates)
Chart 0.9.1 → 0.10.0 (minor: new configuration options)
Chart 0.9.1 → 1.0.0 (major: breaking changes in values structure)

App 5.2.1 → 5.2.2 (patch: FeatBit bug fixes)
App 5.2.1 → 5.3.0 (minor: new FeatBit features)
App 5.2.1 → 6.0.0 (major: breaking API changes)
```

## Step 2: Update Chart.yaml

Update version information in `charts/featbit/Chart.yaml`:

```yaml
# Chart version - increment based on changes
version: 0.9.2  # Was 0.9.1

# FeatBit application version
appVersion: "5.3.0"  # Was "5.2.1"
```

**Version Update Commands:**
```bash
# Navigate to chart directory
cd charts/featbit

# Edit Chart.yaml
code Chart.yaml  # Or use your preferred editor

# Verify changes
git diff Chart.yaml
```

**Chart Version Decision Tree:**
```
Chart Changes?
├─ Breaking changes in values.yaml structure? → MAJOR (1.0.0)
├─ New optional configuration options? → MINOR (0.10.0)
├─ Bug fixes in templates? → PATCH (0.9.2)
└─ Only appVersion update? → PATCH (0.9.2)
```

## Step 3: Update Image Tags in values.yaml

Update all FeatBit component image tags in `charts/featbit/values.yaml`:

### Core Components (4 images to update)

```yaml
# 1. UI Component (line ~49)
ui:
  image:
    tag: 5.3.0  # Update from 5.2.1

# 2. API Server (line ~143)
api:
  image:
    tag: 5.3.0  # Update from 5.2.1

# 3. Evaluation Server (line ~235)
els:
  image:
    tag: 5.3.0  # Update from 5.2.1

# 4. DA Server (line ~327)
da-server:
  image:
    tag: 5.3.0  # Update from 5.2.1
```

**Bulk Update Commands:**
```bash
cd charts/featbit

# Search for current version tags
grep -n "tag: 5.2.1" values.yaml

# Use sed to replace (verify first!)
sed -i 's/tag: 5.2.1/tag: 5.3.0/g' values.yaml

# Verify changes (should show 4 changes)
git diff values.yaml
```

**Manual Update Locations:**
```
Line ~49:  ui.image.tag
Line ~143: api.image.tag  
Line ~235: els.image.tag
Line ~327: da-server.image.tag
```

### Infrastructure Components (Optional)

Only update if new versions are required:
- PostgreSQL (line ~415)
- MongoDB (line ~482)
- Redis (line ~556-564)
- Kafka (line ~586-652)
- ClickHouse (varies)

## Step 4: Create Database Migration (If Needed)

If the new FeatBit version includes database schema changes:

### 4.1 Create Migration File

```bash
# Create new migration file
touch migration/RELEASE-v0.9.2.md

# Or for major releases
touch migration/RELEASE-v1.0.0.md
```

### 4.2 Migration File Template

```markdown
# FeatBit Chart v0.9.2 / App v5.3.0 Database Migration

## Overview
Brief description of database changes in this release.

## Prerequisites
- FeatBit version: 5.2.x or earlier
- Target version: 5.3.0
- Database: PostgreSQL 13+ or MongoDB 5+

## PostgreSQL Migrations

### Schema Changes

#### Add New Columns
\`\`\`sql
-- Add feature analytics column
ALTER TABLE feature_flags 
ADD COLUMN analytics_enabled BOOLEAN DEFAULT false;

-- Add last accessed timestamp
ALTER TABLE feature_flags 
ADD COLUMN last_accessed_at TIMESTAMP;
\`\`\`

#### Create New Indexes
\`\`\`sql
-- Index for performance optimization
CREATE INDEX idx_feature_flags_analytics 
ON feature_flags(analytics_enabled) 
WHERE analytics_enabled = true;

CREATE INDEX idx_feature_flags_last_accessed 
ON feature_flags(last_accessed_at DESC);
\`\`\`

#### Data Migrations (if needed)
\`\`\`sql
-- Migrate existing data
UPDATE feature_flags 
SET analytics_enabled = true 
WHERE flag_type = 'release';
\`\`\`

## MongoDB Migrations

### Schema Changes

\`\`\`javascript
// Add new fields to feature flags collection
db.featureFlags.updateMany(
  {},
  {
    $set: {
      analyticsEnabled: false,
      lastAccessedAt: null
    }
  }
);

// Create indexes
db.featureFlags.createIndex(
  { analyticsEnabled: 1 },
  { 
    name: "idx_analytics_enabled",
    partialFilterExpression: { analyticsEnabled: true }
  }
);

db.featureFlags.createIndex(
  { lastAccessedAt: -1 },
  { name: "idx_last_accessed" }
);
\`\`\`

## Verification

### PostgreSQL
\`\`\`sql
-- Verify new columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'feature_flags' 
AND column_name IN ('analytics_enabled', 'last_accessed_at');

-- Verify indexes created
SELECT indexname FROM pg_indexes 
WHERE tablename = 'feature_flags';
\`\`\`

### MongoDB
\`\`\`javascript
// Verify fields
db.featureFlags.findOne({}, { analyticsEnabled: 1, lastAccessedAt: 1 });

// Verify indexes
db.featureFlags.getIndexes();
\`\`\`

## Rollback Procedure

If rollback is needed:

### PostgreSQL
\`\`\`sql
-- Remove new columns (if needed)
ALTER TABLE feature_flags DROP COLUMN analytics_enabled;
ALTER TABLE feature_flags DROP COLUMN last_accessed_at;

-- Drop indexes
DROP INDEX IF EXISTS idx_feature_flags_analytics;
DROP INDEX IF EXISTS idx_feature_flags_last_accessed;
\`\`\`

### MongoDB
\`\`\`javascript
// Remove fields
db.featureFlags.updateMany({}, {
  $unset: { analyticsEnabled: "", lastAccessedAt: "" }
});

// Drop indexes
db.featureFlags.dropIndex("idx_analytics_enabled");
db.featureFlags.dropIndex("idx_last_accessed");
\`\`\`

## Notes
- Always backup database before migration
- Test migration on non-production environment first
- Migration is backward-compatible with FeatBit 5.2.x
- Estimated execution time: < 1 minute for small datasets
```

### 4.3 Migration File Naming Convention

```
migration/RELEASE-v{chart-version}.md

Examples:
migration/RELEASE-v0.9.2.md
migration/RELEASE-v0.10.0.md
migration/RELEASE-v1.0.0.md
```

## Step 5: Document Environment Variables & Breaking Changes

### 5.1 Check for Environment Variable Changes

Review FeatBit release notes for new or changed env vars:

**Common env variable locations in chart:**
- `templates/_*-env.tpl` files
- ConfigMaps in deployment files
- values.yaml defaults

**Document changes:**
```markdown
## Environment Variable Changes

### New Variables (v5.3.0)
- `ANALYTICS_ENABLED` - Enable feature analytics (default: false)
- `ANALYTICS_RETENTION_DAYS` - Data retention period (default: 90)

### Changed Variables
- `REDIS_CONNECTION_TIMEOUT` - Default increased from 5s to 10s
- `DATABASE_POOL_SIZE` - Default changed from 20 to 50

### Deprecated Variables
- `OLD_FEATURE_TOGGLE` - Replaced by `NEW_FEATURE_FLAG`
- `LEGACY_API_MODE` - Removed in v6.0.0

### Migration Guide
\`\`\`yaml
# Old configuration (v5.2.x)
env:
  - name: OLD_FEATURE_TOGGLE
    value: "true"

# New configuration (v5.3.0)
env:
  - name: NEW_FEATURE_FLAG
    value: "enabled"
\`\`\`
```

### 5.2 Document Breaking Changes

**Breaking Change Categories:**
1. **Configuration Structure Changes**
2. **API Endpoint Changes**
3. **SDK Compatibility Changes**
4. **Database Schema Incompatibilities**
5. **Removed Features**

**Breaking Changes Template:**
```markdown
## Breaking Changes in v5.3.0

### ⚠️ Configuration Structure
**Changed:** `api.auth` configuration structure
**Impact:** Custom auth values must be updated
**Migration:**
\`\`\`yaml
# Before (v5.2.x)
api:
  auth:
    enabled: true
    provider: "oauth"

# After (v5.3.0)
api:
  auth:
    mode: "oauth"
    providers:
      - name: "oauth"
        enabled: true
\`\`\`

### ⚠️ API Changes
**Removed:** `/api/v1/legacy-flags` endpoint
**Impact:** Clients using old API must migrate
**Alternative:** Use `/api/v2/feature-flags`

### ⚠️ SDK Compatibility
**Minimum Versions Required:**
- JavaScript SDK: >= 2.0.0
- .NET SDK: >= 3.0.0
- Java SDK: >= 2.5.0
**Action:** Update SDK versions before upgrading

### ⚠️ Database Changes
**Required:** Schema migration mandatory
**Impact:** Cannot rollback after migration without data loss
**Action:** Backup database before upgrade
```

### 5.3 Update Chart README

Update `charts/featbit/README.md` or `charts/featbit/examples/` documentation:

```markdown
## Changes in v0.9.2 / App v5.3.0

### Features
- Added analytics tracking for feature flags
- Improved performance with new database indexes
- Enhanced API rate limiting

### Configuration Changes
- New `analyticsEnabled` field in values.yaml
- Updated default resource limits

### Migration Required
- Database schema changes - see migration/RELEASE-v0.9.2.md
- Update SDK versions if using JavaScript < 2.0.0

### Breaking Changes
- Auth configuration structure updated
- Legacy API endpoints removed
```

## Step 6: Test Locally

Before publishing, test the updated chart locally:

```bash
# Update local dependencies
cd charts/featbit
helm dependency update

# Test with local PostgreSQL
kubectl config use-context docker-desktop
helm upgrade featbit-test . \
  -f examples/standard/featbit-standard-local-pg.yaml \
  --dry-run

# If dry-run succeeds, deploy
helm upgrade featbit-test . \
  -f examples/standard/featbit-standard-local-pg.yaml

# Verify pods
kubectl get pods -w

# Test health endpoints
kubectl port-forward service/featbit-api 5000:5000
curl http://localhost:5000/health

# Test UI
kubectl port-forward service/featbit-ui 8081:8081
# Visit: http://localhost:8081
```

## Step 7: Publish Release

### 7.1 Update Chart Repository

```bash
# Package chart
helm package charts/featbit

# Update index (if managing repo)
helm repo index . --url https://charts.featbit.co

# Push changes
git add charts/featbit/Chart.yaml
git add charts/featbit/values.yaml
git add migration/RELEASE-v*.md
git commit -m "Release chart v0.9.2 with FeatBit v5.3.0"
git tag -a v0.9.2 -m "Release v0.9.2"
git push origin main --tags
```

### 7.2 Create GitHub Release

1. Go to https://github.com/featbit/featbit-charts/releases/new
2. Tag: `v0.9.2`
3. Title: `FeatBit Helm Chart v0.9.2 (App v5.3.0)`
4. Description template:

```markdown
# FeatBit Helm Chart v0.9.2

## Application Version
FeatBit v5.3.0

## What's Changed

### Features
- Added analytics tracking for feature flags
- Improved database performance with new indexes

### Chart Improvements
- Updated default resource recommendations
- Added new configuration options for analytics

### Breaking Changes
⚠️ **Configuration Structure Updated**
- Auth configuration now uses nested `providers` structure
- See migration guide below

⚠️ **Database Migration Required**
- New columns and indexes added to feature_flags table
- See `migration/RELEASE-v0.9.2.md` for scripts

## Upgrade Instructions

### 1. Review Migration
\`\`\`bash
cat migration/RELEASE-v0.9.2.md
\`\`\`

### 2. Backup Database
\`\`\`bash
pg_dump -h <host> -U <user> featbit > backup.sql
\`\`\`

### 3. Execute Migrations
Follow instructions in `migration/RELEASE-v0.9.2.md`

### 4. Upgrade Chart
\`\`\`bash
helm repo update featbit
helm upgrade featbit featbit/featbit \
  --version 0.9.2 \
  -f your-values.yaml
\`\`\`

## SDK Compatibility

**Minimum Required Versions:**
- JavaScript SDK: >= 2.0.0
- .NET SDK: >= 3.0.0
- Java SDK: >= 2.5.0

## Documentation
- [Chart README](https://github.com/featbit/featbit-charts/blob/main/charts/featbit/README.md)
- [FeatBit Docs](https://docs.featbit.co/)
- [Migration Guide](https://github.com/featbit/featbit-charts/blob/main/migration/RELEASE-v0.9.2.md)

## Full Changelog
https://github.com/featbit/featbit-charts/compare/v0.9.1...v0.9.2
```

## Complete Example Workflow

```bash
# ============================================
# STEP 1: Update Chart.yaml
# ============================================
cd charts/featbit
# Edit Chart.yaml:
#   version: 0.9.2
#   appVersion: "5.3.0"

# ============================================
# STEP 2: Update values.yaml image tags
# ============================================
# Update 4 image tags: ui, api, els, da-server
# All from 5.2.1 → 5.3.0

# ============================================
# STEP 3: Create Migration File
# ============================================
cat > ../../migration/RELEASE-v0.9.2.md << 'EOF'
# FeatBit v0.9.2 Migration
... (migration content) ...
EOF

# ============================================
# STEP 4: Test Locally
# ============================================
kubectl config use-context docker-desktop
helm upgrade featbit-test . \
  -f examples/standard/featbit-standard-local-pg.yaml \
  --dry-run

helm upgrade featbit-test . \
  -f examples/standard/featbit-standard-local-pg.yaml

kubectl get pods -w

# ============================================
# STEP 5: Commit and Publish
# ============================================
cd ../..
git add charts/featbit/Chart.yaml
git add charts/featbit/values.yaml
git add migration/RELEASE-v0.9.2.md
git commit -m "Release v0.9.2 with FeatBit v5.3.0"
git tag -a v0.9.2 -m "Release v0.9.2"
git push origin main --tags

# ============================================
# STEP 6: Create GitHub Release
# ============================================
# Go to GitHub UI and create release from tag v0.9.2
```

## Files to Update

| File | What to Update |
|------|----------------|
| `charts/featbit/Chart.yaml` | `version` and `appVersion` |
| `charts/featbit/values.yaml` | Image tags for ui, api, els, da-server |
| `migration/RELEASE-v{version}.md` | Database migration scripts (if needed) |
| `charts/featbit/README.md` | Release notes and documentation |
| `charts/featbit/examples/` | Example configurations (if changed) |

## Checklist Before Publishing

- [ ] Chart.yaml version updated
- [ ] Chart.yaml appVersion updated
- [ ] All 4 image tags updated in values.yaml
- [ ] Migration file created (if needed)
- [ ] Breaking changes documented
- [ ] Environment variable changes documented
- [ ] Tested locally with dry-run
- [ ] Tested actual deployment locally
- [ ] All pods running and healthy
- [ ] Health endpoints responding
- [ ] Git changes committed
- [ ] Git tag created
- [ ] Changes pushed to repository
- [ ] GitHub release created with notes

## Common Mistakes to Avoid

❌ **Forgetting to update all 4 image tags** - Must update ui, api, els, da-server  
❌ **Chart version doesn't follow SemVer** - Use MAJOR.MINOR.PATCH  
❌ **No migration file for schema changes** - Users need migration scripts  
❌ **Breaking changes not documented** - Users need migration guides  
❌ **Not testing locally first** - Catch issues before publishing  
❌ **Forgetting to update dependencies** - Run `helm dependency update`  
❌ **Not documenting env variable changes** - Users need configuration guide  

## Tools Required

- Helm >= 3.7.0
- Git
- kubectl (for local testing)
- Docker Desktop with Kubernetes enabled
- Text editor (VS Code recommended)

## Support

- **Repository**: https://github.com/featbit/featbit-charts
- **Issues**: https://github.com/featbit/featbit-charts/issues
- **FeatBit Docs**: https://docs.featbit.co/
