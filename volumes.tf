module "coreos-image" {
  source = "./download_coreos"
}

resource "libvirt_volume" "coreos" {
  name   = "os_image-coreos"
  source = module.coreos-image.image_path

  depends_on = [
    module.coreos-image
  ]
}