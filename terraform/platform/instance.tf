locals {
  user_data = templatefile("${path.module}/templates/cloud.yml.tftpl", {
    user = local.vars.ansible_user
    key  = trimspace(file(pathexpand("${local.vars.ssh_key}.pub")))
  })
}

resource "incus_instance" "router" {
  name     = "router"
  type     = "virtual-machine"
  image    = incus_image.base.fingerprint
  profiles = []

  config = {
    "limits.cpu"           = local.router.cpu
    "limits.memory"        = local.router.memory
    "cloud-init.user-data" = local.user_data
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      path = "/"
      pool = incus_storage_pool.infra.name
      size = local.router.disk
    }
  }

  device {
    name = "eth0"
    type = "nic"

    properties = {
      network        = incus_network.lab_10.name
      "ipv4.address" = local.router.nics.lab_10
    }
  }

  device {
    name = "eth1"
    type = "nic"

    properties = {
      network        = incus_network.lab_20.name
      "ipv4.address" = local.router.nics.lab_20
    }
  }
}

resource "incus_instance" "vm" {
  for_each = local.internal

  name     = each.key
  type     = "virtual-machine"
  image    = incus_image.base.fingerprint
  profiles = []

  config = {
    "limits.cpu"                 = each.value.cpu
    "limits.memory"              = each.value.memory
    "cloud-init.user-data"       = local.user_data
    "security.protection.delete" = each.value.protected
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      path = "/"
      pool = incus_storage_pool.infra.name
      size = each.value.disk
    }
  }

  device {
    name = "eth0"
    type = "nic"

    properties = {
      network                   = incus_network.lab_20.name
      "ipv4.address"            = each.value.address
      "security.acls"           = local.acls[each.key]
      "security.ipv4_filtering" = "true"
    }
  }
}
