variable "name" {
  description = "Tenant slug, e.g. privacyguides. Used for the pool id, role id, and CI user."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.name))
    error_message = "Tenant name must be lowercase alphanumeric/hyphen."
  }
}

variable "comment" {
  description = "Human-readable tenant description (shown on the pool)."
  type        = string
  default     = ""
}

variable "sdn_zone" {
  description = "SDN zone containing the tenant's allowed VNets."
  type        = string
  default     = "primary"
}

variable "vnets" {
  description = "SDN VNets the tenant may attach VMs to (SDN.Use)."
  type        = list(string)
  default     = []
}

variable "datastores" {
  description = "Datastores the tenant may allocate from."
  type        = list(string)
  default     = []
}

variable "create_token" {
  description = "Create a CI user + API token for this tenant (skip for pool-only tenants managed from the core repo)."
  type        = bool
  default     = true
}

variable "template_vmids" {
  description = "Shared template VMIDs this tenant may clone (grants VM.Clone+VM.Audit on each, nothing more)."
  type        = list(number)
  default     = []
}
