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
    # NB: VM.Monitor existed through PVE 8 but was removed in PVE 9 —
    # including it makes role creation fail with "invalid privilege".
    # PVE 9 instead has granular guest-agent privileges; the provider needs
    # the read-only one to poll agent-reported network interfaces.
    "VM.GuestAgent.Audit",
    "VM.PowerMgmt",
    "VM.Snapshot",
    "VM.Snapshot.Rollback",
    "Datastore.Audit",
    "Datastore.AllocateSpace",
    "SDN.Use",
    # Scoped by the ACL to the tenant's own pool: lets the tenant manage
    # membership of (and create VMs into) their pool, nothing more.
    "Pool.Allocate",
    "Pool.Audit",
  ]
}

# All tenant permissions are granted to this group. Members: the CI user
# below, plus any human operator users (added via their user resources'
# `groups` attribute — e.g. tenant ops who get scoped web UI access).
resource "proxmox_virtual_environment_group" "this" {
  group_id = var.name
  comment  = var.comment != "" ? var.comment : "Tenant ${var.name}"
}

resource "proxmox_virtual_environment_user" "ci" {
  count = var.create_token ? 1 : 0

  user_id = "tofu-${var.name}@pve"
  comment = "CI deploy user for tenant ${var.name} (token auth only)"
  enabled = true
  groups  = [proxmox_virtual_environment_group.this.group_id]
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
  path      = "/pool/${var.name}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  group_id  = proxmox_virtual_environment_group.this.group_id
  propagate = true
}

# Allowed VNets: attaching NICs requires SDN.Use on the vnet path.
resource "proxmox_acl" "vnet" {
  for_each = toset(var.vnets)

  path      = "/sdn/zones/${var.sdn_zone}/${each.value}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  group_id  = proxmox_virtual_environment_group.this.group_id
  propagate = true
}

# Allowed datastores: disk + cloud-init volume allocation.
resource "proxmox_acl" "datastore" {
  for_each = toset(var.datastores)

  path      = "/storage/${each.value}"
  role_id   = proxmox_virtual_environment_role.this.role_id
  group_id  = proxmox_virtual_environment_group.this.group_id
  propagate = true
}

# Shared templates live outside tenant pools; cloning one needs VM.Clone on
# the template itself. This grants clone+read ONLY — the tenant cannot
# modify or delete the template.
resource "proxmox_virtual_environment_role" "templates" {
  count = length(var.template_vmids) > 0 ? 1 : 0

  role_id    = "tenant-${var.name}-templates"
  privileges = ["VM.Clone", "VM.Audit"]
}

resource "proxmox_acl" "template" {
  for_each = toset([for v in var.template_vmids : tostring(v)])

  path      = "/vms/${each.value}"
  role_id   = proxmox_virtual_environment_role.templates[0].role_id
  group_id  = proxmox_virtual_environment_group.this.group_id
  propagate = false
}
