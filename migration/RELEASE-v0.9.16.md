# FeatBit Chart v0.9.16 / App v5.4.9 Migration Guide

## Overview

This release updates FeatBit from **5.4.7** to **5.4.9**, including the targeting validation
and client data synchronization fixes in **5.4.8** and the optional UI setting in **5.4.9**.

No new database migration is required. If upgrading from a chart earlier than `0.9.14`,
review the intermediate migration guides first, including the database changes in
[RELEASE-v0.9.11.md](./RELEASE-v0.9.11.md) and the Cosmos DB index requirement in
[RELEASE-v0.9.14.md](./RELEASE-v0.9.14.md).

## Release Information

- **Chart Version**: 0.9.16 (from 0.9.15)
- **FeatBit App Version**: 5.4.9 (from 5.4.7)
- **Application Image Tags**: UI, API, evaluation server, and data analytics server use `5.4.9`.
- **Release Notes**: [5.4.8](https://github.com/featbit/featbit/releases/tag/5.4.8),
  [5.4.9](https://github.com/featbit/featbit/releases/tag/5.4.9)
- **Full Changelog**: [5.4.7...5.4.9](https://github.com/featbit/featbit/compare/5.4.7...5.4.9)

## What's Changed

### FeatBit 5.4.8

- Invalid or incomplete feature flag and segment targeting configurations can no longer be saved.
- The evaluation server logs malformed targeting data in more detail.
- Evaluation failures for individual flags or segments no longer interrupt Client SDK data
  synchronization for the entire environment.

### FeatBit 5.4.9

- The UI can hide the environment secrets popover in the header using
  `SHOW_ENV_SECRETS_IN_HEADER`. Environment switching and access permissions are unchanged.

### Chart Configuration

- The AKS Front Door example uses the correct `das` key for data analytics server settings,
  so its image, service, and resource overrides take effect.

## Migration Requirements

### Database and Dependency Changes

None. FeatBit 5.4.8 and 5.4.9 add no PostgreSQL or MongoDB migration scripts, and this
chart release keeps the existing infrastructure dependency versions.

### Environment Variable and Configuration Changes

The new UI environment variable `SHOW_ENV_SECRETS_IN_HEADER` defaults to `true`, preserving
the existing behavior. To hide the header's environment secrets popover, use the existing
`ui.env` field:

```yaml
ui:
  env:
    - name: SHOW_ENV_SECRETS_IN_HEADER
      value: "false"
```

Use the quoted string `"false"`. Helm replaces environment variable lists, so retain any
other `ui.env` entries in the same list. See the
[upstream UI configuration reference](https://github.com/featbit/featbit/blob/5.4.9/modules/front-end/README.md).

### Breaking Changes

There are no chart configuration breaking changes or required new environment variables.
Applications or automation that save invalid or incomplete targeting configurations must
correct those configurations to pass the stricter validation introduced in 5.4.8.

## Upgrade Steps

If your values files pin FeatBit image tags, update `ui.image.tag`, `api.image.tag`,
`els.image.tag`, and `das.image.tag` to `5.4.9`, including any local or backup values
files used for upgrades. `--reuse-values` alone preserves old explicit image tags.

```bash
helm repo update featbit
helm upgrade featbit featbit/featbit \
  --namespace featbit \
  --version 0.9.16 \
  -f your-values.yaml
```

## Verification

```bash
kubectl get pods -n featbit
helm history featbit -n featbit
kubectl get deployments -n featbit \
  -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[*].image}{"\n"}{end}'
```

Confirm that enabled FeatBit components use image tag `5.4.9`, targeting configurations
save successfully, and Client SDK data synchronization works. If the new UI option is
configured, verify that the header secrets popover is hidden and environment switching
still works.
