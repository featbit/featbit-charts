# FeatBit Chart v0.10.5 / App v6.1.2 Release Notes

Previous release: **Chart 0.10.4 / FeatBit 6.1.2**.

The FeatBit application version is unchanged. See the
[FeatBit v6.1.2 release notes](https://github.com/featbit/featbit/releases/tag/6.1.2).

## Chart changes

- Add `busybox.enabled` (default `true`). Set it to `false` to skip the built-in BusyBox
  startup waits for the UI, API and Evaluation Server. Custom init containers
  (`extraInitContainers`) and LoadBalancer auto-discovery keep their own settings.
- Add optional `global.azure.images.<ui|api|els>` image settings (`registry`, `image`, `tag`)
  for Azure Marketplace packaging. A component with an entry uses it in preference to its
  standard image settings and `global.imageRegistry`; components without one are unchanged.
- Add `charts/featbit/examples/marketplace`: a values overlay, an optional Azure Key Vault
  `SecretProviderClass`, and packaging notes.
- Add `tests/helm/marketplace-images.sh`, run in the Helm Tests and Release Charts workflows.

## Important notes

- No breaking configuration changes or database migration are required when upgrading from
  Chart 0.10.4.
- Without `global.azure.images`, the chart renders the same images and startup waits as 0.10.4.
- `helm upgrade --reuse-values` from 0.10.4 keeps the BusyBox startup waits. A missing
  `busybox.enabled` counts as `true`; only an explicit `false` removes them.

Validation includes offline Helm checks, the existing PostgreSQL/ClickHouse rendering tests and
the new image/BusyBox rendering tests. The Standard tier with bundled PostgreSQL and Redis was
deployed on a local Kubernetes cluster with BusyBox waits on and off, and the UI and SDK were
checked against it. An `--reuse-values` upgrade from 0.10.4 was checked with a dry run. The
Azure Marketplace packaging check has not been run yet.
