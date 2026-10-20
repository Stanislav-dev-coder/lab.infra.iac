resource "incus_network" "lab_10" {
  name = "lab_10"

  config = {
    "ipv4.address" = "${local.vars.networks.lab_10.address}/${local.vars.networks.lab_10.prefix}"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
    "raw.dnsmasq" = chomp(<<-EOT
      local=/${local.vars.domain}/
      address=/${local.vars.domain}/${local.router.nics.lab_10}
      bogus-priv
    EOT
    )
  }
}

resource "incus_network_acl" "lab_20" {
  name = "lab20"
}

resource "incus_network" "lab_20" {
  name = "lab_20"

  config = {
    "ipv4.address"      = "${local.vars.networks.lab_20.address}/${local.vars.networks.lab_20.prefix}"
    "ipv4.nat"          = "false"
    "ipv4.dhcp.gateway" = local.router.nics.lab_20
    "ipv6.address"      = "none"
    "security.acls"     = incus_network_acl.lab_20.name
    "raw.dnsmasq" = chomp(<<-EOT
      local=/${local.vars.domain}/
      address=/${local.vars.domain}/${local.router.nics.lab_20}
      bogus-priv
    EOT
    )
  }
}
