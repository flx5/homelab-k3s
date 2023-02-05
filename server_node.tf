data "ct_config" "coreos-k3s-server" {
  content = templatefile("coreos-k3s.yaml", {
    K3S_ARGS = {
      K3S_TOKEN = random_password.k3s_token.result
    }
    MANIFESTS = {
      dashboard = file("manifests/dashboard.yml")
    }
  })
  strict       = true
  pretty_print = false

  snippets = [
  ]
}

resource "libvirt_ignition" "coreos-k3s-server" {
  name    = "ignition_server"
  content = data.ct_config.coreos-k3s-server.rendered
}

resource "libvirt_volume" "coreos-k3s-server" {
  name           = "coreos-k3s-server.qcow2"
  base_volume_id = libvirt_volume.coreos.id

  lifecycle {
    replace_triggered_by = [
      libvirt_ignition.coreos-k3s-server
    ]
  }
}

resource "libvirt_domain" "coreos-k3s-server" {
  name   = "coreos-k3s-server"
  memory = "1024"
  vcpu   = 1

  coreos_ignition = libvirt_ignition.coreos-k3s-server.id

  disk {
    volume_id = libvirt_volume.coreos-k3s-server.id
  }

  network_interface {
    network_id     = libvirt_network.kube_network.id
    hostname       = "coreos-k3s-server"
    wait_for_lease = true
  }
}


