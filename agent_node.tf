
data "ct_config" "coreos-k3s-agent" {
  content      = templatefile("coreos-k3s.yaml", {
    K3S_ARGS = {
      K3S_TOKEN = random_password.k3s_token.result
      K3S_URL = "https://${libvirt_domain.coreos-k3s-server.network_interface.0.addresses.0}:6443"
    }
    MANIFESTS = {

    }
  })
  strict       = true
  pretty_print = false

  snippets = [
  ]
}

resource "libvirt_ignition" "coreos-k3s-agent" {
  name = "ignition_agent"
  content = data.ct_config.coreos-k3s-agent.rendered
}

resource "libvirt_volume" "coreos-k3s-agent" {
  name           = "coreos-k3s-agent.qcow2"
  base_volume_id = libvirt_volume.coreos.id

  lifecycle {
    replace_triggered_by = [
      libvirt_ignition.coreos-k3s-server
    ]
  }
}

resource "libvirt_domain" "coreos-k3s-agent" {
  name   = "coreos-k3s-agent"
  memory = "2048"
  vcpu   = 1

  coreos_ignition = libvirt_ignition.coreos-k3s-agent.id

  disk {
    volume_id = libvirt_volume.coreos-k3s-agent.id
  }

  network_interface {
    network_id     = libvirt_network.kube_network.id
    hostname       = "coreos-k3s-agent"
    wait_for_lease = true
  }
}
