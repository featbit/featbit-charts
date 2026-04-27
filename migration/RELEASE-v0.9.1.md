# FeatBit Helm Chart v0.9.1 - Upgrade Summary

## Overview
This release updates the FeatBit Helm chart to version **0.9.1** to support FeatBit application version **5.2.1**.

## What's Changed

### Application Version
- **FeatBit**: Upgraded from `v5.2.0` to `v5.2.1`

### Breaking Changes
**None** - This is a patch release with no breaking changes.

### Database Migration Scripts

FeatBit v5.2.1 includes important database schema updates that **must be applied before upgrading**. Migration scripts are available for both supported database backends.

#### MongoDB (v5.2.1.js)
The migration script includes:

- **Fix Incorrect Developer Policy ID** ([#836](https://github.com/featbit/featbit/pull/836))
  - Corrects the developer policy UUID from `66f3687f-939f-4257-bd3f-c3553d39e1b6` to `66f3687f-939d-4257-bd3f-c3553d39e1b6`
  - Updates all references in Organizations, MemberPolicies, and GroupPolicies collections
  
- **Add Key Field to Policies** ([#841](https://github.com/featbit/featbit/pull/841))
  - Adds a new `key` field to the Policies collection
  - Automatically generates keys from policy names using slugification
  - Ensures uniqueness per organization with deduplication logic

#### PostgreSQL (v5.2.1.sql)
The migration script includes identical functionality as MongoDB:
- Fixes incorrect developer_policy_id in policies table
- Updates all references in organizations, member_policies, and group_policies tables
- Adds `key` column to policies table with automatic slug generation
- Ensures key uniqueness per organization

### Files Modified
1. `charts/featbit/Chart.yaml`
   - Version: `0.9.1`
   - AppVersion: `5.2.1` (no change)

2. `charts/featbit/templates/mongodb-init-scripts-configmap.yaml`
   - Added: `06_v5.2.1.js` with MongoDB migration script

3. `charts/featbit/templates/postgresql-init-scripts-configmap.yaml`
   - Added: `07_v5.2.1.sql` with PostgreSQL migration script

## Upgrade Instructions

### ⚠️ Important: Pre-Upgrade Steps

**You MUST run the database migration scripts BEFORE upgrading the Helm chart.**

#### For MongoDB Users

1. **Backup your database first**
2. **Download the migration script**:
   ```bash
   curl -O https://raw.githubusercontent.com/featbit/featbit/main/infra/mongodb/docker-entrypoint-initdb.d/v5.2.1.js
   ```

3. **Apply the migration script**:
   ```bash
   # If using embedded MongoDB in the cluster
   kubectl exec -it <mongodb-pod-name> -n <namespace> -- mongosh featbit /path/to/v5.2.1.js
   
   # If using external MongoDB
   mongosh mongodb://<connection-string>/featbit v5.2.1.js
   ```

#### For PostgreSQL Users

1. **Backup your database first**
2. **Download the migration script**:
   ```bash
   curl -O https://raw.githubusercontent.com/featbit/featbit/main/infra/postgresql/docker-entrypoint-initdb.d/v5.2.1.sql
   ```

3. **Apply the migration script**:
   ```bash
   # If using embedded PostgreSQL in the cluster
   kubectl exec -it <postgresql-pod-name> -n <namespace> -- psql -U postgres -d featbit -f /path/to/v5.2.1.sql
   
   # If using external PostgreSQL
   psql -h <host> -U <username> -d featbit -f v5.2.1.sql
   ```

### Helm Upgrade

After applying the database migration scripts:

```bash
helm upgrade featbit featbit/featbit \
  --version 0.9.1 \
  -f your-values.yaml \
  --namespace your-namespace
```

### For New Installations

#### Using Embedded Database (mongodb.enabled=true or postgresql.enabled=true)
The migration scripts will be applied automatically during initial database setup through the ConfigMaps:
- MongoDB: `06_v5.2.1.js` will be executed automatically
- PostgreSQL: `07_v5.2.1.sql` will be executed automatically

#### Using External Database
You must manually apply the migration scripts to your external database before the first installation. Follow the same steps as described in the "Pre-Upgrade Steps" section above.

## References

### Migration Scripts
- [FeatBit v5.2.1 Migration - MongoDB Script](https://github.com/featbit/featbit/blob/main/infra/mongodb/docker-entrypoint-initdb.d/v5.2.1.js)
- [FeatBit v5.2.1 Migration - PostgreSQL Script](https://github.com/featbit/featbit/blob/main/infra/postgresql/docker-entrypoint-initdb.d/v5.2.1.sql)
- [All MongoDB Migration Scripts](https://github.com/featbit/featbit/blob/main/infra/mongodb/docker-entrypoint-initdb.d/)
- [All PostgreSQL Migration Scripts](https://github.com/featbit/featbit/blob/main/infra/postgresql/docker-entrypoint-initdb.d/)

### Related Pull Requests
- [Pull Request #836 - Fix Developer Policy ID](https://github.com/featbit/featbit/pull/836)
- [Pull Request #841 - Add Policy Keys](https://github.com/featbit/featbit/pull/841)

## Questions or Issues?

If you encounter any problems during the upgrade:
1. Check your database backup is complete
2. Review the migration script logs for errors
3. Open an issue at: https://github.com/featbit/featbit-charts/issues
