# FeatBit Chart v0.10.1 / App v6.0.1 Upgrade Guide

Upgrade from Chart **0.10.0 / FeatBit 6.0.0** to **0.10.1 / 6.0.1**.

## Changes and migration requirements

The release maintainer confirmed that this update only changes the application
image tags. No new database schema migration, values or environment variable
changes are required relative to FeatBit 6.0.0.

This chart updates `appVersion` and the UI/API/ELS default and public example
image tags to `6.0.1`. Infrastructure dependencies and initialization scripts
remain unchanged.

Upstream 6.0.1 release notes and the tag comparison could not be retrieved during
preparation; independent upstream confirmation remains pending. Check the
[upstream releases](https://github.com/featbit/featbit/releases) for published notes.

When upgrading from FeatBit 5.x or an earlier chart, first follow the
[0.10.0 migration guide](RELEASE-v0.10.0.md), including the manual migrations
against your configured PostgreSQL/MongoDB and, for Professional, ClickHouse
databases. Helm does not execute existing-database migrations.

## Upgrade

Update or remove any explicit `ui.image.tag`, `api.image.tag` and `els.image.tag`
pins in your override files, including private `*.local.yaml` files. All three
must select `6.0.1`. `appVersion` alone does not select these images, and
`--reuse-values` can retain old image tags and other defaults.

Before using `--reset-values`, prepare a complete reviewed override file containing
all desired JWT settings, database/Redis credentials or Secret references,
persistence settings, external API/ELS URLs and other deployment settings. Retain
the previous values, chart package and database backups for recovery.

From the repository root, upgrade using the source chart:

```bash
helm upgrade featbit ./charts/featbit \
  --namespace featbit \
  --reset-values \
  -f your-reviewed-values.yaml
```

For a published package, run `helm repo update featbit` and confirm
`helm show chart featbit/featbit --version 0.10.1` reports app version `6.0.1`.
Only after confirming availability, replace `./charts/featbit` in the command
above with `featbit/featbit --version 0.10.1`.

## Verification

Confirm enabled UI/API/ELS Deployments use image tag and `VERSION` value `6.0.1`.
Check UI `/health`, API/ELS `/health/liveness` and `/health/readiness`, login,
SDK evaluation and live updates. For Professional, also check Kafka ingestion
and ClickHouse queries.

Offline Helm lint and rendering passed for chart defaults, Standard PostgreSQL,
Standard MongoDB, bundled Professional, and synthetic external AKS, Front Door
and Professional configurations. Rendered application images, `VERSION` values
and chart metadata match this release. The existing PostgreSQL password rendering
regression also passed.

Target-version runtime testing and database operations are not performed as part
of this chart preparation. Offline Helm validation does not establish runtime
health. Helm rollback does not reverse any earlier database migrations.
