# FeatBit Chart v0.9.14 / App v5.4.7 Migration Guide

## Overview

This release updates FeatBit from **5.4.4** to **5.4.7**. It includes UI and data analytics runtime maintenance, a login fix, and a Cosmos DB compatibility fix for end-user search.

There are no PostgreSQL schema changes, MongoDB document migrations, or environment variable changes. However, **Cosmos DB users must add one compound index** required by FeatBit 5.4.7.

If you are upgrading from a version earlier than FeatBit 5.4.1, first review and apply the database migration documented in [RELEASE-v0.9.11.md](./RELEASE-v0.9.11.md).

## Release Information

- **Chart Version**: 0.9.14 (from 0.9.13)
- **FeatBit App Version**: 5.4.7 (from 5.4.4)
- **Release Notes**:
  - https://github.com/featbit/featbit/releases/tag/5.4.5
  - https://github.com/featbit/featbit/releases/tag/5.4.6
  - https://github.com/featbit/featbit/releases/tag/5.4.7
- **Full Changelog**:
  - https://github.com/featbit/featbit/compare/5.4.4...5.4.7

## What's Changed

### FeatBit 5.4.5

- Upgrade Nginx in the UI image; its base image moves from Debian 11 (bullseye) to Debian 13 (trixie).
- Fix login when the first project has no environments.

### FeatBit 5.4.6

- Update the data analytics server runtime from Python 3.9 on Debian 12 to Python 3.10 on Debian 13.
- Update Flask to 2.2.5, Werkzeug to 2.3.8, and Gunicorn to 22.0.0 as security maintenance.

### FeatBit 5.4.7

- Replace the Cosmos DB-incompatible `$unionWith` aggregation with parallel queries and application-side result merging.
- Require a compound index on the Cosmos DB `EndUsers` collection for the new query path.

## Migration Requirements

### Prerequisites

- Current Version: FeatBit 5.4.4
- Target Version: FeatBit 5.4.7
- Kubernetes: >= 1.23
- Helm: >= 3.7.0

### Database Changes

#### PostgreSQL

None. FeatBit 5.4.5 through 5.4.7 contain no PostgreSQL schema changes or migration scripts.

#### MongoDB

No document or schema migration is required for native MongoDB deployments.

#### Azure Cosmos DB for MongoDB

Required. Connect to the FeatBit database and create the following compound index:

```javascript
db.EndUsers.createIndex({ updatedAt: -1, _id: -1 });
```

Verify that the index exists:

```javascript
db.EndUsers.getIndexes();
```

### Environment Variable and Configuration Changes

None. No new chart values or user-configurable environment variables are required.

### Breaking Changes

There are no chart configuration breaking changes. If you build derivative images from the official UI or data analytics images, retest them against the Debian and runtime base-image updates described above.