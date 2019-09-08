locals {
  server_name = "prometheus-${var.dc}"
}

data "vsphere_virtual_machine" "template" {
  datacenter_id = var.vsphere_datacenter_id
  name          = var.template
}

resource "vsphere_virtual_machine" "prometheus-vm" {
  name             = local.server_name
  folder           = var.folder
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id
  num_cpus         = 1
  memory           = 512
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    linked_clone  = true
    customize {
      linux_options {
        host_name = local.server_name
        domain    = "${var.sub}.${var.domain}"
      }
      network_interface {
      }
    }
  }

  # https://www.terraform.io/docs/provisioners/connection.html#example-usage
  connection {
    host     = self.default_ip_address
    type     = "ssh"
    user     = "ubuntu"
    password = "ubuntu"
  }

  disk {
    label            = "disk0"
    eagerly_scrub    = false
    thin_provisioned = true
    size             = data.vsphere_virtual_machine.template.disks[0].size
  }

  network_interface {
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
    network_id   = var.network_id
  }

  # https://www.terraform.io/docs/provisioners/remote-exec.html#example-usage
  provisioner "remote-exec" {
    inline = [
      "curl -sLo /tmp/public_keys.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/provision/add_github_user_public_keys.sh",
      "GITHUB_USER=kikitux bash /tmp/public_keys.sh",
      "export DC=${var.dc}",
      "export IFACE=${var.iface}",
      "export LAN_JOIN='${var.consul_lan_join}'",
      "curl -sLo /tmp/consul.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/consul-client/consul.sh",
      "sudo -E bash /tmp/consul.sh",
      "curl -sLo /tmp/prometheus.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/provision/prometheus.sh",
      "sudo -E bash /tmp/prometheus.sh",
      "curl -sLo /tmp/node_exporter.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/provision/node_exporter.sh",
      "sudo -E bash /tmp/node_exporter.sh",
    ]
  }
}

output "guest_ip_address" {
  value = vsphere_virtual_machine.prometheus-vm.guest_ip_addresses[0]
}

output "name" {
  value = local.server_name
}

