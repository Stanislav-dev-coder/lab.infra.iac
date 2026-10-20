resource "incus_network_acl" "internal" {
  name = "internal"

  egress = [
    {
      action      = "allow"
      state       = "enabled"
      description = "any"
    },
  ]

  ingress = [
    {
      action           = "allow"
      state            = "enabled"
      protocol         = "tcp"
      source           = "${local.router.nics.lab_20}/32"
      destination_port = "22"
      description      = "ssh from router"
    },
    {
      action           = "allow"
      state            = "enabled"
      protocol         = "tcp"
      source           = "${local.internal.monitoring.address}/32"
      destination_port = "9100"
      description      = "node_exporter from monitoring"
    },
  ]
}

resource "incus_network_acl" "app" {
  name = "app"

  ingress = [
    {
      action           = "allow"
      state            = "enabled"
      protocol         = "tcp"
      source           = "${local.router.nics.lab_20}/32"
      destination_port = "8080"
      description      = "app from router"
    },
  ]
}

resource "incus_network_acl" "gitlab" {
  name = "gitlab"

  ingress = [
    {
      action           = "allow"
      state            = "enabled"
      protocol         = "tcp"
      source           = "${local.router.nics.lab_20}/32"
      destination_port = "80,5050,2222"
      description      = "web, registry and git ssh from router"
    },
  ]
}

resource "incus_network_acl" "monitoring" {
  name = "monitoring"

  ingress = [
    {
      action           = "allow"
      state            = "enabled"
      protocol         = "tcp"
      source           = "${local.router.nics.lab_20}/32"
      destination_port = "3000"
      description      = "grafana from router"
    },
  ]
}

locals {
  acls = {
    app        = "${incus_network_acl.internal.name},${incus_network_acl.app.name}"
    gitlab     = "${incus_network_acl.internal.name},${incus_network_acl.gitlab.name}"
    monitoring = "${incus_network_acl.internal.name},${incus_network_acl.monitoring.name}"
    runner     = incus_network_acl.internal.name
  }
}
