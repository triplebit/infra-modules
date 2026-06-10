output "pool_id" {
  value = proxmox_virtual_environment_pool.this.pool_id
}

output "role_id" {
  value = proxmox_virtual_environment_role.this.role_id
}

output "ci_user_id" {
  value = var.create_token ? proxmox_virtual_environment_user.ci[0].user_id : null
}

output "ci_token" {
  description = "Full API token (user@realm!name=secret) for the tenant's CI. Retrieve once with `tofu output -raw ...` and store on the tenant's runner."
  value       = var.create_token ? proxmox_user_token.ci[0].value : null
  sensitive   = true
}
