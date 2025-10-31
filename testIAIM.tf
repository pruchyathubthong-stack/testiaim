terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.6.1"
    }
  }
}

provider "vsphere" {
  user                 = "administrator@vsphere.local"
  password             = "P@ssw0rd"
  vsphere_server       = "10.200.124.40"
  allow_unverified_ssl = true
}

# --- vSphere Data ---
data "vsphere_datacenter" "dc" {
  name = "MCC-IBM3650-Datacenter"
}

data "vsphere_datastore" "datastore" {
  name          = "datastore1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "MCC-IBM3650-Cluster"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "VLAN-124"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "Ubuntu-2404-Template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# --- VM Resource ---
resource "vsphere_virtual_machine" "ubuntu_vm" {
  name             = "ubuntu2404-test01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 2048
  guest_id = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = 100
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "ubuntu2404-test01"
        domain    = "local"
      }

      network_interface {
        ipv4_address = "10.200.124.226"
        ipv4_netmask = 23
      }

      ipv4_gateway = "10.200.124.1"
    }
  }
}

# --- Wait for SSH port 22 ---
resource "null_resource" "wait_for_ssh" {
  depends_on = [vsphere_virtual_machine.ubuntu_vm]

  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready!'"]
    connection {
      type     = "ssh"
      host     = "10.200.124.226"
      user     = "nawineed"
      password = "nawineed"
      port     = 22
      timeout  = "10m"
    }
  }
}

# --- Ansible Provision (commented out for now) ---
# resource "null_resource" "ansible_provision" {
#   depends_on = [null_resource.wait_for_ssh]
# 
#   triggers = {
#     always_run = timestamp()
#   }
# 
#   provisioner "local-exec" {
#     command = <<EOT
# ansible-playbook -i 10.200.124.226, -u nawineed --extra-vars "ansible_password=nawineed ansible_become_password=nawineed" /root/terrafrom/ubuntuins.yml
# EOT
#   }
# }