# Database Migration Guide

Critical information about FeatBit database migrations during upgrades.

## Overview

FeatBit Helm chart does **NOT** automatically execute database migrations. All schema changes must be applied manually by a database administrator before upgrading the application.

## Migration Files Location

```
featbit-charts/
└── migration/
    ├── RELEASE-v0.9.0.md
    ├── RELEASE-v0.9.1.md
    └── RELEASE-v{version}.md
```

Each release version has a corresponding migration file if database changes are required.

## Pre-Upgrade Migration Workflow

### Step 1: Identify Required Migrations

```bash
# List all available migration files
ls migration/

# Find migration for target version
ls migration/RELEASE-v<target-version>.md
```

### Step 2: Review Migration Scripts

```bash
# Read the migration file
cat migration/RELEASE-v<target-version>.md

# Example: Review v0.9.1 migration
cat migration/RELEASE-v0.9.1.md
```

### Step 3: Backup Database

**PostgreSQL Backup:**
```bash
# Full database backup
pg_dump -h <host> -U <username> -d featbit > featbit_backup_$(date +%Y%m%d).sql

# Or using kubectl if database is in cluster
kubectl exec -n <namespace> <postgres-pod> -- pg_dump -U postgres featbit > backup.sql
```

**MongoDB Backup:**
```bash
# Full database backup
mongodump --host <host> --port 27017 --db featbit --out backup_$(date +%Y%m%d)

# Or using kubectl
kubectl exec -n <namespace> <mongo-pod> -- mongodump --db featbit --out /tmp/backup
kubectl cp <namespace>/<mongo-pod>:/tmp/backup ./backup
```

### Step 4: Execute Migrations

**For PostgreSQL:**
```bash
# Connect to database
psql -h <host> -U <username> -d featbit

# Or via kubectl
kubectl exec -it -n <namespace> <postgres-pod> -- psql -U postgres -d featbit

# Execute migration script (copy SQL from migration file)
-- Example migration:
ALTER TABLE feature_flags ADD COLUMN last_modified_by VARCHAR(255);
CREATE INDEX idx_feature_flags_last_modified ON feature_flags(last_modified_at);
```

**For MongoDB:**
```bash
# Connect to database
mongosh --host <host> --port 27017 featbit

# Or via kubectl
kubectl exec -it -n <namespace> <mongo-pod> -- mongosh featbit

# Execute migration script (copy commands from migration file)
// Example migration:
db.featureFlags.createIndex({ "lastModifiedAt": 1 });
db.featureFlags.updateMany({}, { $set: { "lastModifiedBy": null } });
```

### Step 5: Verify Migrations

```bash
# PostgreSQL: Check schema changes
\dt                          # List tables
\d feature_flags             # Describe specific table
\di                          # List indexes

# MongoDB: Check collections
db.getCollectionNames()      # List collections
db.featureFlags.getIndexes() # Check indexes
```

## Migration Best Practices

### 1. Always Backup First
- Take full database backup before any migration
- Verify backup can be restored
- Store backup in secure location
- Keep backups for at least 30 days

### 2. Test in Non-Production First
- Run migrations on staging/dev environment first
- Verify application works after migration
- Check for data integrity issues
- Measure migration execution time

### 3. Coordinate with Team
- Schedule maintenance window if needed
- Notify stakeholders of downtime
- Have DBA review migration scripts
- Prepare rollback plan

### 4. Monitor During Migration
- Watch for lock timeouts
- Monitor database performance
- Check for blocking queries
- Track migration progress

### 5. Verify After Migration
- Run schema validation queries
- Check data integrity
- Test application connectivity
- Verify all indexes created

## Migration Checklist

Before proceeding with Helm upgrade:

- [ ] Migration file exists for target version
- [ ] Database backup completed and verified
- [ ] Migration scripts reviewed by DBA
- [ ] Tested migration in non-production environment
- [ ] Maintenance window scheduled (if required)
- [ ] Team notified
- [ ] Migrations executed successfully
- [ ] Schema changes verified
- [ ] Data integrity confirmed
- [ ] Application can connect to database

## Rollback Procedure

If application fails after migration:

### Option 1: Rollback Database
```bash
# PostgreSQL: Restore from backup
psql -h <host> -U <username> -d featbit < featbit_backup.sql

# MongoDB: Restore from backup
mongorestore --host <host> --port 27017 --db featbit backup/featbit
```

### Option 2: Rollback Application Only
```bash
# If database migration is backward compatible
helm rollback <release-name> <previous-revision> -n <namespace>
```

## Common Migration Scenarios

### Adding New Column
```sql
-- PostgreSQL
ALTER TABLE table_name ADD COLUMN new_column VARCHAR(255) DEFAULT 'default_value';

-- MongoDB
db.collection.updateMany({}, { $set: { "newField": null } });
```

### Adding Index
```sql
-- PostgreSQL
CREATE INDEX idx_name ON table_name(column_name);

-- MongoDB
db.collection.createIndex({ "fieldName": 1 });
```

### Data Transformation
```sql
-- PostgreSQL
UPDATE table_name SET new_column = old_column WHERE condition;

-- MongoDB
db.collection.updateMany({ condition }, { $set: { "newField": "$oldField" } });
```

### Dropping Column (Backward Compatible Approach)
```sql
-- Step 1: Deploy new version that doesn't use the column
-- Step 2: After successful deployment, drop the column

-- PostgreSQL
ALTER TABLE table_name DROP COLUMN old_column;

-- MongoDB
db.collection.updateMany({}, { $unset: { "oldField": "" } });
```

## Examples from Actual Releases

### RELEASE-v0.9.1 Example
```bash
# Read the actual migration file
cat migration/RELEASE-v0.9.1.md

# Follow instructions in that file
# May include:
# - Schema modifications
# - Data migrations
# - Index additions
# - Configuration changes
```

## Getting Help

If you encounter migration issues:

1. Check migration file comments for specific instructions
2. Review FeatBit documentation: https://docs.featbit.co/
3. Search GitHub issues: https://github.com/featbit/featbit-charts/issues
4. Contact FeatBit support with:
   - Current version
   - Target version
   - Database type (PostgreSQL/MongoDB)
   - Error messages
   - Migration steps attempted
