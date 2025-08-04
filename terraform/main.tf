terraform {
  required_providers {
    libvirt = {
        source  = "dmacvicar/libvirt"
        version = "0.8.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

#pool for group virt
resource "libvirt_pool" "k8s_pool" {
    name = "k8s_pool"
    type = "dir"
    path = "/var/lib/libvirt/images/k8s_pool"
}

#base image
resource "libvirt_volume" "base" {
    name = "base.qcow2"
    pool = libvirt_pool.k8s_pool.name
    source = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
    format = "qcow2"
}

# create disk by role
resource "libvirt_volume" "vm_disk" {
  for_each = toset(var.machine_names)
  name = "k8s-${each.key}.qcow2"
  pool = libvirt_pool.k8s_pool.name
  base_volume_id = libvirt_volume.base.id
  size = var.machine_size
}

resource "libvirt_cloudinit_disk" "cloudinit" {
    for_each = toset(var.machine_names)
    name = "cloudinit-${each.key}.iso"
    pool = libvirt_pool.k8s_pool.name
    user_data = templatefile("${path.module}/cloud_init.yml", {
        hostname = "k8s-${each.key}",
        ssh_key = file("~/.ssh/id_rsa.pub")
    })
}

resource "libvirt_domain" "k8s_node" {
    for_each = toset(var.machine_names)
    name = "k8s-${each.key}"
    memory = each.key == "master" ? 4096 : 2048
    vcpu = each.key == "master" ? 2 : 1
    cloudinit = libvirt_cloudinit_disk.cloudinit[each.key].id

    network_interface {
        network_name = "default"
        wait_for_lease = true
    }

    disk {
        volume_id = libvirt_volume.vm_disk[each.key].id
    }

    console {
        type = "pty"
        target_port = "0"
        target_type = "serial"
    }

    graphics {
        type        = "spice"
        listen_type = "address"
        autoport    = true
    }
}

