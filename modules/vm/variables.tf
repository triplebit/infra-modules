variable "name" {
  description = "VM name / hostname, e.g. us-mn-garage1."
  type        = string
}

variable "node" {
  description = "Proxmox node to place the VM on."
  type        = string
}

variable "pool_id" {
  description = "Resource pool (tenant boundary). Tenant VMs must set this."
  type        = string
  default     = null
}

variable "allow_unpooled" {
  description = "Explicit escape hatch for core platform VMs that must live outside tenant pools."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Proxmox tags, e.g. [\"tenant-privacyguides\", \"role-ghost\"]. Drives Ansible dynamic inventory."
  type        = list(string)
  default     = []
}

variable "description" {
  type    = string
  default = "Managed by OpenTofu."
}

variable "template_vmid" {
  description = "VMID of the template to clone."
  type        = number
}

variable "bridge" {
  description = "SDN VNet / bridge name, e.g. v100. The VNet applies the VLAN tag."
  type        = string
}

variable "vlan_id" {
  description = "VLAN number (e.g. 100 for v100). Used only to derive the VMID; set null on networks outside the VMID convention and pass vmid_override instead."
  type        = number
  default     = null
}

variable "ip_cidr" {
  description = "Static IPv4 in CIDR notation, e.g. 23.188.56.117/27. Must come from this tenant's allocation in ipam.yaml."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ip_cidr))
    error_message = "ip_cidr must be IPv4 CIDR notation, e.g. 23.188.56.117/27."
  }
}

variable "gateway" {
  description = "IPv4 default gateway."
  type        = string
}

variable "ip6_cidr" {
  description = "Optional static IPv6 in CIDR notation (e.g. 2602:f81c:8::117/64), or \"auto\" for SLAAC."
  type        = string
  default     = null
}

variable "ip6_gateway" {
  description = "IPv6 default gateway. Ignored when ip6_cidr is null or \"auto\"."
  type        = string
  default     = null
}

variable "vmid_override" {
  description = "Explicit VMID. Overrides the derived first-digit-of-VLAN*1000 + last-octet value (used for imported VMs that predate the convention, or networks without one)."
  type        = number
  default     = null
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_gb" {
  type    = number
  default = 20
}

variable "datastore" {
  description = "Datastore for the disk and cloud-init drive, e.g. the Ceph pool name. Differs per site."
  type        = string
}

variable "template_node" {
  description = "Node holding the template's configuration (e.g. the site's image-build node). Leave null when the template lives on var.node."
  type        = string
  default     = null
}

variable "ci_user" {
  description = "cloud-init user account (the bootstrap/operator user; team members are added post-install via Ansible)."
  type        = string
  default     = "jonah"
}

variable "ssh_keys" {
  description = "SSH public keys for the cloud-init user."
  type        = list(string)
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "startup_order" {
  description = "Optional boot order priority."
  type        = number
  default     = null
}

variable "extra_networks" {
  description = "Additional NICs beyond the primary; order maps to net1, net2, ... and their cloud-init ip_config slots."
  type = list(object({
    bridge      = string
    ip_cidr     = optional(string)
    gateway     = optional(string)
    ip6_cidr    = optional(string)
    ip6_gateway = optional(string)
    firewall    = optional(bool, false)
  }))
  default = []
}

variable "nic_firewall" {
  description = "Enable the PVE firewall on the primary NIC. Required on sites with the cluster firewall active (e.g. swift) for VM-level rules/security groups to apply; no-op elsewhere."
  type        = bool
  default     = false
}
