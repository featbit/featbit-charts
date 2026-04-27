# FeatBit Chart v0.9.6 / App v5.3.2 Migration Guide

## Overview

This release updates FeatBit to version **5.3.2**. It includes **breaking database schema changes** and must be migrated before upgrading.

## Release Information

- **Chart Version**: 0.9.6 (from 0.9.5)
- **FeatBit App Version**: 5.3.2 (from 5.3.1)
- **Release Notes**: https://github.com/featbit/featbit/releases/tag/5.3.2

## What's Changed

- ✨ feat: fine-grained access control for segments ([#885](https://github.com/featbit/featbit/pull/885))
- 🐛 fix: failed to load member filtering options ([#886](https://github.com/featbit/featbit/pull/886))
- ✨ feat: track workspace usage ([#888](https://github.com/featbit/featbit/pull/888))
- ✨ feat: workspace usage UI ([#889](https://github.com/featbit/featbit/pull/889))

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.3.1
- Target Version: FeatBit 5.3.2
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Breaking Changes

⚠️ **Database migration required** — This release introduces schema changes that must be applied **before** upgrading.

---

## Database Migration Scripts

### PostgreSQL

Run against your FeatBit database **before** upgrading:

```sql
\connect featbit

-- https://github.com/featbit/featbit/pull/885
-- Replace the legacy 'ManageSegment' action with the wildcard '*' in all policy statements.
UPDATE policies
SET statements = (
    SELECT COALESCE(
        jsonb_agg(
            jsonb_set(
                elem,
                '{actions}',
                (
                    SELECT COALESCE(
                        jsonb_agg(
                            CASE
                                WHEN action = '"ManageSegment"'::jsonb THEN '"*"'::jsonb
                                ELSE action
                            END
                        ),
                        '[]'::jsonb
                    )
                    FROM jsonb_array_elements(elem->'actions') AS action
                )
            )
        ),
        '[]'::jsonb
    )
    FROM jsonb_array_elements(statements) AS elem
)
WHERE statements IS NOT NULL;

-- Append a new 'allow all' statement for the segment resource type to the built-in
-- admin and developer policies.
UPDATE policies
SET statements = statements || jsonb_build_array(
    jsonb_build_object(
        'id', gen_random_uuid(),
        'effect', 'allow',
        'actions', jsonb_build_array('*'),
        'resources', jsonb_build_array('project/*:env/*:segment/*'),
        'resourceType', 'segment'
    )
)
WHERE id IN (
    '3e961f0f-6fd4-4cf4-910f-52d356f8cc08', -- admin
    '66f3687f-939d-4257-bd3f-c3553d39e1b6'  -- developer
);

-- Mirror the same 'ManageSegment' -> '*' action migration for access token permissions.
UPDATE access_tokens
SET permissions = (
    SELECT COALESCE(
        jsonb_agg(
            jsonb_set(
                elem,
                '{actions}',
                (
                    SELECT COALESCE(
                        jsonb_agg(
                            CASE
                                WHEN action = '"ManageSegment"'::jsonb THEN '"*"'::jsonb
                                ELSE action
                            END
                        ),
                        '[]'::jsonb
                    )
                    FROM jsonb_array_elements(elem->'actions') AS action
                )
            )
        ),
        '[]'::jsonb
    )
    FROM jsonb_array_elements(permissions) AS elem
)
WHERE permissions IS NOT NULL;

-- https://github.com/featbit/featbit/pull/888
-- Monthly unique end users per environment.
CREATE TABLE usage_end_user_stats (
    env_id        uuid         NOT NULL,
    year_month    integer      NOT NULL, -- format YYYYMM, e.g. 202604
    user_key      varchar(512) NOT NULL,
    first_seen_at date         NOT NULL,
    CONSTRAINT pk_usage_end_user_stats PRIMARY KEY (env_id, year_month, user_key)
);

CREATE INDEX ix_usage_end_user_stats_env_date
    ON usage_end_user_stats (env_id, first_seen_at);

-- Daily aggregated metrics per environment.
CREATE TABLE usage_event_stats (
    env_id           uuid    NOT NULL,
    stats_date       date    NOT NULL,
    flag_evaluations integer NOT NULL DEFAULT 0,
    custom_metrics   integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_usage_event_stats PRIMARY KEY (env_id, stats_date)
);
```

### MongoDB

Run against your FeatBit database **before** upgrading:

```javascript
const dbName = "featbit";
print('use', dbName, 'database')
db = db.getSiblingDB(dbName);

// https://github.com/featbit/featbit/pull/885
// Replace the legacy 'ManageSegment' action with the wildcard '*' in all policy statements.
db.Policies.updateMany(
    { "statements.actions": "ManageSegment" },
    [{
        $set: {
            statements: {
                $map: {
                    input: "$statements",
                    as: "stmt",
                    in: {
                        $mergeObjects: [
                            "$$stmt",
                            {
                                actions: {
                                    $map: {
                                        input: "$$stmt.actions",
                                        as: "action",
                                        in: { $cond: [{ $eq: ["$$action", "ManageSegment"] }, "*", "$$action"] }
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        }
    }]
);

// Append a new 'allow all' statement for the segment resource type to the built-in
// admin and developer policies.
db.Policies.updateMany(
    {
        _id: {
            $in: [
                UUID("3e961f0f-6fd4-4cf4-910f-52d356f8cc08"),
                UUID("66f3687f-939d-4257-bd3f-c3553d39e1b6")
            ]
        }
    },
    {
        $push: {
            statements: {
                _id: UUID().toString().split('"')[1],
                effect: "allow",
                actions: ["*"],
                resources: ["project/*:env/*:segment/*"],
                resourceType: "segment"
            }
        }
    }
);

// Mirror the same 'ManageSegment' -> '*' action migration for access token permissions.
db.AccessTokens.updateMany(
    { "permissions.actions": "ManageSegment" },
    [{
        $set: {
            permissions: {
                $map: {
                    input: "$permissions",
                    as: "perm",
                    in: {
                        $mergeObjects: [
                            "$$perm",
                            {
                                actions: {
                                    $map: {
                                        input: "$$perm.actions",
                                        as: "action",
                                        in: { $cond: [{ $eq: ["$$action", "ManageSegment"] }, "*", "$$action"] }
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        }
    }]
);

// https://github.com/featbit/featbit/pull/888
// Daily aggregated metrics per environment.
db.UsageEventStats.createIndex({ envId: 1, statsDate: 1 }, { unique: true });

// Monthly unique end users per environment.
db.UsageEndUserStats.createIndex({ envId: 1, yearMonth: 1, userKey: 1 }, { unique: true });
db.UsageEndUserStats.createIndex({ envId: 1, firstSeenAt: 1 });
```

---

## Upgrade Steps

1. **Apply database migration** (see scripts above)
2. **Update Helm chart**:
   ```bash
   helm repo update
   helm upgrade featbit featbit/featbit \
     --version 0.9.6 \
     -f your-values.yaml \
     --namespace featbit
   ```
3. **Verify all pods are running**:
   ```bash
   kubectl get pods -n featbit
   ```

## Rollback

If rollback is needed:
```bash
helm rollback featbit -n featbit
```

> ⚠️ Database migrations cannot be auto-rolled back. Restore from backup if needed.
