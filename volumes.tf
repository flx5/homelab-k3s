module "coreos-image" {
  source = "./download_coreos"
}

resource "null_resource" "debug" {
  provisioner "local-exec" {
    command = "tree"
  }

  depends_on = [
    module.coreos-image
  ]
}

resource "libvirt_volume" "coreos" {
  name   = "os_image-coreos"
  source = module.coreos-image.image_path
}