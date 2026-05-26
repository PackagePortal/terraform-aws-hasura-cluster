# Upgrade Guide

This document collects migration steps for each breaking release of
`terraform-aws-hasura-cluster`. Entries are newest first. For a high-level summary of every
release, see [CHANGELOG.md](CHANGELOG.md).

---

## <a name="v200"></a>v2.0.0 — name-keyed extra secrets

### What changed

Previous versions declared the extra-secret resources with `count`, so each entry in
`hasura_secrets` and `actions_endpoints_secrets` was tracked positionally
(`aws_secretsmanager_secret.other_secrets[0]`, `[1]`, ...). Reordering or removing an entry
caused Terraform to plan a destroy + recreate on every AWS Secrets Manager secret that
followed it.

These resources are now keyed by the user-supplied `name`, which is stable against
reordering and insertions. The new addresses are:

- `aws_secretsmanager_secret.other_secrets["<name>"]`
- `aws_secretsmanager_secret_version.other_secrets["<name>"]`
- `aws_secretsmanager_secret.actions_endpoints_secrets["<name>"]`
- `aws_secretsmanager_secret_version.actions_endpoints_secrets["<name>"]`

A `lifecycle { prevent_destroy = true }` is set on both secret resources as a safety net:
if the migration is incomplete, `terraform plan` will error rather than destroy a secret.

### Migrating

Terraform `moved` blocks must be literal (no `for_each`, no expressions), so the moves
cannot live inside the module — they must be added at your root, alongside the
`module "..." { ... }` block that calls this module. Do this **in the same PR** that bumps
the module version.

1. **Generate `moved.tf`** with the bundled helper. From your root module directory:

   ```sh
   ./scripts/generate-secret-moves.sh module.<your-module-name> moved.tf
   ```

   The script derives the `<env_name>-<app_name>-` prefix automatically from the ECS
   cluster resource already in state, strips it from each AWS secret name to recover the
   key, and emits paired `moved` blocks for both the secret and its `_version`.

2. **Commit `moved.tf`** in the same PR that bumps `version` on the module call.

3. **`terraform plan`** — expect output that contains only state moves under
   "Terraform will perform the following moves" and reports `0 to add, 0 to change, 0 to destroy`.

4. **Apply**, then delete `moved.tf` (move blocks are one-shot — once the state matches the
   new addresses they are no-ops and can be removed).

### Hand-written example

If you'd rather write the blocks yourself instead of using the helper:

```terraform
# Suppose your call looks like:
# hasura_secrets = [
#   { name = "MY_SUPER_SECRET_APP_SETTING", value = ... },
#   { name = "ANOTHER_SECRET",              value = ... },
# ]

moved {
  from = module.example.aws_secretsmanager_secret.other_secrets[0]
  to   = module.example.aws_secretsmanager_secret.other_secrets["MY_SUPER_SECRET_APP_SETTING"]
}
moved {
  from = module.example.aws_secretsmanager_secret_version.other_secrets[0]
  to   = module.example.aws_secretsmanager_secret_version.other_secrets["MY_SUPER_SECRET_APP_SETTING"]
}
moved {
  from = module.example.aws_secretsmanager_secret.other_secrets[1]
  to   = module.example.aws_secretsmanager_secret.other_secrets["ANOTHER_SECRET"]
}
moved {
  from = module.example.aws_secretsmanager_secret_version.other_secrets[1]
  to   = module.example.aws_secretsmanager_secret_version.other_secrets["ANOTHER_SECRET"]
}
```

Repeat the pattern for `actions_endpoints_secrets`. The indices on the `from` side must
match the order the secrets had in the previous `hasura_secrets` /
`actions_endpoints_secrets` list — i.e. the order that produced the existing state.

### Heads-up: the `prevent_destroy` guard

The lifecycle guard catches missed/incorrect moves at plan time, which is what you want
during the upgrade. As a side effect, **intentionally removing** an entry from
`hasura_secrets` or `actions_endpoints_secrets` will also error out. To delete a secret:

1. Temporarily remove the `lifecycle { prevent_destroy = true }` block from this module's
   `secrets.tf` (vendored copy or a fork), or
2. Use `terraform state rm` to drop the secret from state and then let the next plan create
   what's still in your `hasura_secrets` list.

Re-enable the guard before merging.
