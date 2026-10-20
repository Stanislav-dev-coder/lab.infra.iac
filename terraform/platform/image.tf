resource "incus_image" "base" {
  depends_on = [incus_storage_pool.infra]

  source_file = {
    data_path     = "${path.module}/files/ubuntu-26.04-server-cloudimg-amd64.img"
    metadata_path = "${path.module}/files/metadata.tar.xz"
  }

  alias {
    name = local.vars.image
  }
}

output "image_fingerprint" {
  value = incus_image.base.fingerprint
}
