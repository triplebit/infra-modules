output "vmid" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "node" {
  value = proxmox_virtual_environment_vm.this.node_name
}

output "ipv4_address" {
  value = local.ip_address
}
