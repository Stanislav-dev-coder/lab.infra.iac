terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.2.1"
    }
  }
}

locals {
  inventory = yamldecode(file("${path.module}/../../inventory.yml"))
  vars      = local.inventory.all.vars
  router    = local.inventory.all.hosts.router
  internal  = local.inventory.all.children.internal.hosts
}
