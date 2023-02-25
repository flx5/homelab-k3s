resource "bcrypt_hash" "argocd_admin_password" {
  // TODO Change to variable
  cleartext = "changeme"
}

resource "time_static" "argocd_admin_password" {
  triggers = {
    argocd_admin_password = bcrypt_hash.argocd_admin_password.id
  }
}

data "ct_config" "coreos-k3s-server" {
  content = templatefile("coreos-k3s.yaml", {
    ssh_public_key = var.ssh_public_key
    K3S_ARGS = {
      K3S_TOKEN = random_password.k3s_token.result
    }
    MANIFESTS = {
      dashboard = file("manifests/dashboard.yml")
      argocd = <<EOT
apiVersion: v1
kind: Namespace
metadata:
name: argocd
---
${data.http.argocd.response_body}
---
${templatefile("manifests/argocd-secret.yaml", {
    admin = {
        password = base64encode(bcrypt_hash.argocd_admin_password.id)
        passwordMtime = base64encode(time_static.argocd_admin_password.id)
    }
})}
---
${file("manifests/argocd-cmd-params-cm.yaml")}
EOT
    }
  })
  strict       = true
  pretty_print = false

  snippets = [
  ]
}

data "http" "argocd" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/v2.6.2/manifests/install.yaml"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Status code invalid"
    }
  }
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
  memory = "2048"
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


