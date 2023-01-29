terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.11.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system?socket=/var/run/libvirt/virtqemud-sock"
}
