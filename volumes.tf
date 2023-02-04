module "coreos-image" {
  source = "./download_coreos"
}

resource "libvirt_volume" "coreos" {
  name   = "os_image-coreos.qcow2"
  source = module.coreos-image.image_path

  depends_on = [
    module.coreos-image
  ]
}

resource "null_resource" "debug" {
  provisioner "local-exec" {
    command = "ls -l /var/lib/libvirt/images/os_image-coreos.qcow2"
  }

  depends_on = [
    libvirt_volume.coreos
  ]
}