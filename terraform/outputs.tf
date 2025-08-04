output "vm_ips" {
    value = {
        for vm in libvirt_domain.k8s_node: vm.name => vm.network_interface[0].addresses
    }
}