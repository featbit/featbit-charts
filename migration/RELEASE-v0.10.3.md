# FeatBit Chart v0.10.3 / App v6.1.1 Release Notes

Previous release: **Chart 0.10.2 / FeatBit 6.1.0**.

Application features and API changes are covered in the
[FeatBit v6.1.1 release notes](https://github.com/featbit/featbit/releases/tag/6.1.1).

## Chart changes

- Update UI/API/ELS images and AKS/Front Door example pins to **6.1.1**.
- Infrastructure dependencies, configuration fields and initialization scripts remain unchanged.

## Important notes

- Explicit UI/API/ELS image overrides must also select `6.1.1`; `appVersion` alone does not select the images.

Validation includes offline Helm checks and existing PostgreSQL/ClickHouse rendering and initialization-script regressions. Target-version runtime deployment remains unverified.
