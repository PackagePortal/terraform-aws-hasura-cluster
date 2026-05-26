# Changelog

All notable changes to this project are documented here.

This project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0]

### Breaking
- `aws_secretsmanager_secret.other_secrets` / `aws_secretsmanager_secret.actions_endpoints_secrets`
  (and their `_version` counterparts) are now keyed by secret `name` instead of list index.
  Reordering or removing entries no longer destroys unrelated secrets. Consumers upgrading
  from v1.x must add one `moved` block per existing secret at their root in the same PR that
  bumps the module version — see [UPGRADING.md#v200](UPGRADING.md#v200).
- `lifecycle { prevent_destroy = true }` is now set on both extra-secret resources. Missed or
  incorrect `moved` blocks now fail `terraform plan` instead of silently destroying secrets.
  Intentional removal of an entry from `hasura_secrets` / `actions_endpoints_secrets` requires
  temporarily removing the guard for that apply.

### Added
- `scripts/generate-secret-moves.sh` — reads the existing count-indexed state and emits the
  `moved` blocks required for the v2.0.0 migration.
- `validation` blocks on `hasura_secrets` and `actions_endpoints_secrets` rejecting duplicate
  `name` values (the new map key must be unique).

### Changed
- Dropped redundant `depends_on` from the `_version` resources; the `secret_id` reference
  already encodes the dependency.

[2.0.0]: https://github.com/PackagePortal/terraform-aws-hasura-cluster/compare/v1.3.0...v2.0.0
