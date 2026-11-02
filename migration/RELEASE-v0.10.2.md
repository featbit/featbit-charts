# FeatBit Chart v0.10.2 / App v6.1.0 Release Notes

Previous release: **Chart 0.10.1 / FeatBit 6.0.1**.

Application features and API changes are covered in the
[FeatBit v6.1.0 release notes](https://github.com/featbit/featbit/releases/tag/6.1.0).

## Chart changes

- Update UI/API/ELS images and example pins to **6.1.0**. Infrastructure dependencies and configuration fields remain unchanged.
- Append v6.1.0 scripts to fresh bundled PostgreSQL/MongoDB initialization, after v6.0.0.

## Important notes

**Existing PostgreSQL/MongoDB databases require the v6.1.0 migration before
starting 6.1.0 services, including deployments running 6.0.0 or 6.0.1.** Helm does
not execute migrations against existing databases or initialized persistent volumes.

The bundled migration scripts are copied from upstream tag `6.1.0`:

| Database | Migration | Changes |
| --- | --- | --- |
| PostgreSQL | [v6.1.0.sql](../charts/featbit/files/featbit-v6/postgresql-v6.1.0.sql) | Adds `feature_flags.insights_enabled` (default `true`), updates policy/service-token permissions, and migrates audit-log columns, historical records and indexes. |
| MongoDB | [v6.1.0.js](../charts/featbit/files/featbit-v6/mongodb-v6.1.0.js) | Updates policy/service-token permissions, backfills audit-log records and updates indexes. |

- Both scripts default to database `featbit`. PostgreSQL's `\connect` and MongoDB's `dbName` must match the configured database; a client database argument or connection URI does not override those script targets.
- Bootstrap/seed scripts are only for empty databases. Existing data requires the incremental migration above; FeatBit 5.x also requires the earlier [v6 migration](RELEASE-v0.10.0.md).
- Migrations contain multiple operations and may partially apply if interrupted. Retain a verified backup; Helm rollback does not reverse schema or data changes.
- Explicit UI/API/ELS image overrides must also select `6.1.0`; `appVersion` alone does not select the images.
- This release leaves ClickHouse scripts and Kafka topics unchanged from 6.0.x.

Validation includes offline Helm checks and fresh local Standard (PostgreSQL/Redis)
and Professional (PostgreSQL/Redis/Kafka/ClickHouse) deployments. Existing-database
migration execution remains unverified.
