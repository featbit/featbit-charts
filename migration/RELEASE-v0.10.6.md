# FeatBit Chart v0.10.6 / App v6.1.3 Release Notes

Previous release: **Chart 0.10.5 / FeatBit 6.1.2**.

Application features, bug fixes and security changes are covered in the
[FeatBit v6.1.3 release notes](https://github.com/featbit/featbit/releases/tag/6.1.3).

## Chart changes

- Update UI/API/ELS images and the AKS, Front Door and Marketplace example pins to **6.1.3**.
- Update the default image assertions in `tests/helm/marketplace-images.sh`.
- Infrastructure dependencies, configuration fields, templates and initialization scripts remain unchanged.

## New optional application settings

These are application environment variables with built-in defaults. The chart does not set them;
add them through `api.env` / `els.env` only when needed.

- **API** `Authentication__RefreshTokenCookiePath` (default `/api/v1/identity`). If a reverse proxy
  serves the API under a public URL prefix (for example `https://example.com/featbit-api/...`) and
  strips that prefix before forwarding, set this to the public identity path including the prefix,
  so browsers send the refresh-token cookie. A non-empty value must start with `/`. The chart's
  default ingress (`api.ingress.path: /`, no rewrite) does not need it.

  ```yaml
  api:
    env:
      - name: Authentication__RefreshTokenCookiePath
        value: "/featbit-api/api/v1/identity"
  ```

- **Evaluation Server** `StoreAvailability__*` (`CheckIntervalSeconds` 6, `CheckTimeoutMilliseconds`
  2000, `FailureThreshold` 3, `RecoveryThreshold` 5, `MinimumDwellSeconds` 60). These control how the
  Evaluation Server decides to switch between Redis and the database, which fixes repeated switching
  when Redis is intermittently slow. The defaults apply without configuration.

See [modules/back-end/README.md](https://github.com/featbit/featbit/blob/6.1.3/modules/back-end/README.md)
for the API setting.

## Important notes

- No breaking configuration changes or database migration are required when upgrading from
  Chart 0.10.5 / FeatBit 6.1.2. The upstream 6.1.2...6.1.3 comparison contains no database schema
  or initialization script changes.
- Explicit UI/API/ELS image overrides (including `global.azure.images.<ui|api|els>.tag`) must also
  select `6.1.3`; `appVersion` alone does not select the images.
- Do not upgrade with `--reuse-values` alone: it keeps chart 0.10.5's default image tags, so the
  UI/API/ELS pods stay on `6.1.2`. Pass all the values you installed with instead, or add
  `--set ui.image.tag=6.1.3 --set api.image.tag=6.1.3 --set els.image.tag=6.1.3`.
- **Flag trigger management now requires `ToggleFlag`.** In 6.1.2, any user or access token with
  access to a flag's environment could create, enable/disable, reset the token of and delete its
  triggers. In 6.1.3 these actions also require `ToggleFlag` on the flag, and return `403` without
  it ([featbit/featbit#1123](https://github.com/featbit/featbit/pull/1123)). Policies that grant
  flag edit permissions but deliberately leave out `ToggleFlag` lose trigger management after the
  upgrade; add `ToggleFlag` where trigger management should stay. Existing trigger URLs keep
  working, because running a trigger with its token is unchanged.
- FeatBit 6.1.3 also enforces permissions that already existed in 6.1.2 but were not fully checked
  by the server: organization boundaries, segment and environment access, and access to both
  environments plus `CopyFlagTo` for cross-environment flag copy/compare. Policies that follow
  these rules are not affected; requests that only worked because a check was missing now fail.

Validation includes offline Helm checks and the existing PostgreSQL/ClickHouse rendering and
image/BusyBox rendering tests. Target-version runtime deployment remains unverified.
