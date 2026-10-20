resource "incus_storage_pool" "infra" {
  name   = local.vars.pool.name
  driver = local.vars.pool.driver

  config = {
    size = local.vars.pool.size
  }
}
