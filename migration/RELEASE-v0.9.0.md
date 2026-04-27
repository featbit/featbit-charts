# FeatBit Helm Chart v0.9.0 - Upgrade Summary

## Overview
This release updates the FeatBit Helm chart to version **0.9.0** to support FeatBit application version **5.2.0**.

## What's Changed

### Application Version
- **FeatBit**: Upgraded from `v5.1.4` to `v5.2.0`

### Breaking Changes
FeatBit v5.2.0 introduces database schema changes that require migration scripts to be applied. This Helm chart update includes the necessary migration scripts for both supported database backends.

### Database Migration Scripts Added

#### MongoDB (05_v5.2.0.js)
The migration script includes:
- **Segment Tags Support** ([#802](https://github.com/featbit/featbit/pull/802))
  - Adds `tags` field to segments collection
  
- **Custom Flag Sorting** ([#811](https://github.com/featbit/featbit/pull/811))
  - Adds organization-level flag sorting settings
  - Adds `UpdateOrgSortFlagsBy` permission to Administrator policy

- **Enhanced Permission Control (RBAC)** ([#821](https://github.com/featbit/featbit/pull/821))
  - Updates flag permissions from `ManageFeatureFlag` to wildcard `*` for full access
  - Adds environment access permissions for Developer policy (`CanAccessEnv`)
  - Updates environment access permissions for Administrator policy
  - Adds full feature flag access for both Administrator and Developer policies

#### PostgreSQL (06_v5.2.0_migration.sql)
The migration script includes identical functionality as MongoDB:
- Segment tags support
- Custom flag sorting settings
- Enhanced RBAC permissions for environments and feature flags

### Files Modified
1. `charts/featbit/Chart.yaml`
   - Version: `0.9.0`
   - AppVersion: `5.2.0`

2. `charts/featbit/values.yaml`
   - All image tags updated to: `5.2.0`

3. `charts/featbit/templates/mongodb-init-scripts-configmap.yaml`
   - Added: `05_v5.2.0.js` with MongoDB migration script

4. `charts/featbit/templates/postgresql-init-scripts-configmap.yaml`
   - Added: `06_v5.2.0.sql` with PostgreSQL migration script

## Upgrade Instructions

### For New Installations
No special action required. The migration scripts will be applied automatically during initial database setup.

### For Existing Installations
The migration scripts are designed to be idempotent and safe to run on existing databases. However, we recommend:

1. **Backup your database** before upgrading
2. **Test the upgrade** in a non-production environment first
3. **Review the migration scripts** in the ConfigMaps to understand the changes

#### Upgrade Command
```bash
helm upgrade featbit featbit/featbit \
  --version 0.9.0 \
  -f your-values.yaml \
  --namespace your-namespace
```

### Migration Notes
- The migration scripts are executed automatically when using the embedded MongoDB or PostgreSQL instances
- For **external databases**, you will need to manually apply the migration scripts:
  - **MongoDB**: Apply the content from `05_v5.2.0.js`
    - Script: [v5.2.0.js](https://github.com/featbit/featbit/blob/main/infra/mongodb/docker-entrypoint-initdb.d/v5.2.0.js)
  - **PostgreSQL**: Apply the content from `06_v5.2.0.sql`
    - Script: [v5.2.0.sql](https://github.com/featbit/featbit/blob/main/infra/postgresql/docker-entrypoint-initdb.d/v5.2.0.sql)

## New Features in FeatBit v5.2.0

### Enhanced Permission Control (RBAC)
Fine-grained access control for feature flags, including:
- Flag-level permissions
- Dynamic permissions based on feature flag tags
- Environment access controls

### Flag Comparison Helicopter View
- Compare feature flag settings between environments
- Copy settings from source to target
- High-level overview of flag differences across environments

### Miscellaneous Improvements
- Segment tags support
- Custom flag sorting at organization level
- Cross-project flag copying
- Clone existing flags functionality
- Redesigned flag list page

## References
- [FeatBit v5.2.0 Release Notes](https://github.com/featbit/featbit/releases/tag/5.2.0)
- [Full Changelog](https://github.com/featbit/featbit/compare/5.1.4...5.2.0)
- MongoDB Migration: [v5.2.0.js](https://github.com/featbit/featbit/blob/main/infra/mongodb/docker-entrypoint-initdb.d/v5.2.0.js)
- PostgreSQL Migration: [v5.2.0.sql](https://github.com/featbit/featbit/blob/main/infra/postgresql/docker-entrypoint-initdb.d/v5.2.0.sql)

## Compatibility
- Kubernetes: `>=1.23`
- Helm: `>= 3.7.0`
- FeatBit: `5.2.0`

## Support
For issues or questions, please:
- Open an issue: https://github.com/featbit/featbit-charts/issues
- FeatBit documentation: https://docs.featbit.co
