module "coreos-image" {
  source = "./download_coreos"
}

resource "null_resource" "debug" {
  provisioner "local-exec" {
    command = "pwd && tree .terraform"
  }

  depends_on = [
    module.coreos-image
  ]
}

resource "libvirt_volume" "coreos" {
  name   = "os_image-coreos"
  source = module.coreos-image.image_path

  depends_on = [
    module.coreos-image
  ]
}