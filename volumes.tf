module "coreos-image" {
  source = "./download_coreos"
}

resource "null_resource" "debug" {
  provisioner "local-exec" {
    command = "ls /home/runner/work/homelab-k3s/homelab-k3s/.terraform/image_cache/"
  }
}

resource "libvirt_volume" "coreos" {
  name   = "os_image-coreos"
  source = module.coreos-image.image_path
}