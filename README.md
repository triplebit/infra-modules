# infra-modules

Reusable OpenTofu modules, Ansible roles, policy checks, and CI workflows for Proxmox-based
infrastructure operated by Triplebit. Tenant repos consume these; nothing in this repository
is site-specific. No hostnames, addresses, credentials, or topology belong here.

## Layout

- `modules/` — OpenTofu modules (bpg/proxmox provider).
  - `vm/` — Debian cloud-init VM cloned from a template. Derives its VMID from
    VLAN + IP last octet per site convention (overridable for imports).
- `roles/` — shared Ansible roles (base hardening, docker, caddy, garage, powerdns,
  lightningstream, wireguard-gateway, github-runner). *(migration in progress)*
- `policy/` — conftest/OPA policies run against `tofu plan` JSON in CI (pool required,
  IP within the tenant's IPAM allocation, etc.). *(planned)*
- `.github/workflows/` — reusable workflows callable from tenant repos. *(planned)*

## Versioning

Consumers pin a git tag, never a branch:

```hcl
module "ghost" {
  source = "github.com/triplebit/infra-modules//modules/vm?ref=v0.1.0"
  # ...
}
```

## Module conventions

- Every VM takes `pool_id` (the tenant boundary), `bridge` (SDN VNet), and an `ip_cidr`
  that must come from the tenant's allocation in the consuming repo's IPAM registry.
- VMID derivation: first digit of the VLAN × 1000 + last octet of the IPv4 address
  (v100 + .117 → 1117). Pass `vmid_override` for hosts that predate the convention.
- Datastore and template IDs are inputs — they differ per site and per cluster.
