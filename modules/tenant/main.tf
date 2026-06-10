# A tenant = Proxmox-enforced boundary: resource pool + custom role + CI
# user/token whose ACLs cover ONLY the tenant's pool, allowed VNets, and
# allowed datastores. Pools scope permissions, not quotas — resource limits
# are review-time concerns, not enforced here.

resource "proxmox_virtual_environment_pool" "this" {
  pool_id = var.name
  comment = var.comment
}

resource "proxmox_virtual_environment_role" "this" {
  role_id = "tenant-${var.name}"

  privileges = [
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Cloudinit",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Console",
    "VM.Migrate",
    "VM.Monitor",
    "VM.PowerMgmt",
    "VM.Snapshot",
    "VM.Snapshot.Rollback",
    "Datastore.Audit",
    "Datastore.AllocateSpace",
    "SDN.Use",
  ]
}

resource "proxmox_virtual_environment_user" "ci" {
  count = var.create_token ? 1 : 0

  user_id = "tofu-${var.name}@pve"
  comment = "CI deploy user for tenant ${var.name} (token auth only)"
  enabled = true
}

resource "proxmox_user_token" "ci" {
  count = var.create_token ? 1 : 0

  user_id    = proxmox_virtual_environment_user.ci[0].user_id
  token_name = "ci"
  comment    = "Tenant ${var.name} deploy token"
  # Token inherits the user's ACLs (no privilege separation) — ACLs below are
  # granted to the user, which keeps the grant list in one place.
  privileges_separation = false
}

# Pool: full tenant role.
resource "proxmox_acl" "pool" {
  count = var.create_token ? 1 : 0

  path      = "/pool/${var.name}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  user_id   = proxmox_virtual_environment_user.ci[0].user_id
  propagate = true
}

# Allowed VNets: attaching NICs requires SDN.Use on the vnet path.
resource "proxmox_acl" "vnet" {
  for_each = var.create_token ? toset(var.vnets) : []

  path      = "/sdn/zones/${var.sdn_zone}/${each.value}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  user_id   = proxmox_virtual_environment_user.ci[0].user_id
  propagate = true
}

# Allowed datastores: disk + cloud-init volume allocation.
resource "proxmox_acl" "datastore" {
  for_each = var.create_token ? toset(var.datastores) : []

  path      = "/storage/${each.value}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  user_id   = proxmox_virtual_environment_user.ci[0].user_id
  propagate = true
}
