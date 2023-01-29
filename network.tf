resource "libvirt_network" "kube_network" {
  name = "k8snet"

  mode = "nat"
  domain = "k8s.local"

  addresses = ["10.17.3.0/24"]

  dns {
    enabled = true
  }
}
