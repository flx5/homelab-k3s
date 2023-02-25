output "k3s_server_ip" {
  value = coalesce([for iface in libvirt_domain.coreos-k3s-server.network_interface : iface.addresses.0 if length(iface.addresses) > 0]...)
}