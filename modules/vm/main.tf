locals {
  ip_address    = split("/", var.ip_cidr)[0]
  ip_last_octet = tonumber(element(split(".", local.ip_address), 3))

  # Site convention: VMID = first digit of VLAN * 1000 + last octet of the IP.
  # v100 + .117 -> 1117, v300 + .12 -> 3012. IP uniqueness (ipam.yaml) is what
  # guarantees VMID uniqueness across independently-applied tenant repos.
  derived_vmid = var.vlan_id == null ? null : (
    tonumber(substr(tostring(var.vlan_id), 0, 1)) * 1000 + local.ip_last_octet
  )

  vmid = var.vmid_override != null ? var.vmid_override : local.derived_vmid
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  node_name   = var.node
  vm_id       = local.vmid
  pool_id     = var.pool_id
  tags        = var.tags
  description = var.description

  clone {
    vm_id = var.template_vmid
    # The clone API call must target the node OWNING the template's config;
    # PVE then places the new VM on var.node (shared storage required).
    node_name = var.template_node
    full      = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    interface    = "scsi0"
    datastore_id = var.datastore
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  dynamic "network_device" {
    for_each = var.extra_networks
    content {
      bridge   = network_device.value.bridge
      model    = "virtio"
      firewall = network_device.value.firewall
    }
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = var.ip_cidr
        gateway = var.gateway
      }

      dynamic "ipv6" {
        for_each = var.ip6_cidr != null ? [1] : []
        content {
          address = var.ip6_cidr
          gateway = var.ip6_cidr == "auto" ? null : var.ip6_gateway
        }
      }
    }

    # ip_config blocks align positionally with network_device blocks.
    dynamic "ip_config" {
      for_each = var.extra_networks
      content {
        dynamic "ipv4" {
          for_each = ip_config.value.ip_cidr != null ? [1] : []
          content {
            address = ip_config.value.ip_cidr
            gateway = ip_config.value.gateway
          }
        }
        dynamic "ipv6" {
          for_each = ip_config.value.ip6_cidr != null ? [1] : []
          content {
            address = ip_config.value.ip6_cidr
            gateway = ip_config.value.ip6_gateway
          }
        }
      }
    }

    user_account {
      username = var.ci_user
      keys     = var.ssh_keys
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }
  }

  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order = var.startup_order
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Power state and placement are operational, not configuration: node
    # determines initial placement only; afterwards HA/maintenance moves are
    # never reverted, and VMs are never started/stopped on apply.
    ignore_changes = [started, node_name]
  }
}
