resource "proxmox_virtual_environment_pool" "eyedeck_pool" {
  comment = "Managed by Terraform"
  pool_id = "eyedeck-pool"
}

# Create a Ubuntu 23.10 VM Template to clone other Ubuntu VMs from
resource "proxmox_virtual_environment_vm" "ubuntu_23_10_template" {
  name        = "ubuntu-23.10-template"
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu", "template"]

  node_name = "pve"
  
  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
    trim    = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  machine = "q35"

  operating_system {
    type = "l26"
  }

  cpu {
    type    = "x86-64-v2-AES"
    sockets = 1
    cores   = 1
  }

  memory  {
    dedicated = 2048
  }

  on_boot         = false
  started         = false
  template        = true
  stop_on_destroy = true
  
  disk {
    datastore_id  = "local-lvm"
    file_id       = proxmox_virtual_environment_download_file.ubuntu_23_10_cloud_image.id
    interface     = "virtio0"
    iothread      = false
    discard       = "on"
    size          = 20
    file_format   = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  bios = "ovmf"

  efi_disk {
    file_format = "raw"
    type        = "4m"
  }

  tpm_state {
    version = "v2.0"
  }

  lifecycle {
    ignore_changes = [
      started
    ]
  }
}

# Jumphost for EyeDeck
resource "proxmox_virtual_environment_vm" "eyedeck-jh" {
  name        = "eyedeck-jh"
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu", "eyedeck"]

  node_name = "pve"
  
  pool_id = proxmox_virtual_environment_pool.eyedeck_pool.id

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
    trim    = true
  }

  # Clone from Ubuntu 23.10 Template
  clone {
    node_name     = "pve"
    datastore_id  = "local-lvm"
    vm_id         = proxmox_virtual_environment_vm.ubuntu_23_10_template.vm_id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.10.42.5/24"
        gateway = "10.10.42.1"
      }
    }

    dns {
      servers = ["10.10.42.1"]
      domain  = "spyrja.internal"
    }

    user_data_file_id = proxmox_virtual_environment_file.eyedeck_ubuntu_cloud_config.id 
  }

  # The Ubuntu 23.10 template only has a single core
  cpu {
    sockets = 1
    cores   = 2
  }

  started         = true
  on_boot         = true
  stop_on_destroy = true

  # Ubuntu 23.10 at least does not reboot properly on Proxmox 8.1 when reboot=true is set and the
  # guest agent is enabled, regardless of if it is running or not.
  # We work around that by throwing a reboot command at the end of the cloud-init.
  //reboot = true

  # This neeeds to go, oops!
  cdrom {
    file_id = proxmox_virtual_environment_download_file.ubuntu_23_10_cloud_image.id
    enabled = true
  }

  # Increase disk size over the clone
  disk {
    datastore_id  = "local-lvm"
    interface     = "virtio0"
    discard       = "on"
    size          = 60
  }

  # For now, EyeDeck uses the same bridge, just has to set a vlan.
  # One day, I'll figure out how to create SDN zones and such with
  # the proxmox provider.
  network_device {
    bridge  = "vmbr0"
    vlan_id = "42"
  }

  lifecycle {
    ignore_changes = [
      started,
      initialization[0].user_data_file_id,
      clone[0].vm_id
    ]
  }
}

# The cloud config below adds two new users aside from the default ubuntu user
# and uses ssh-import-id to grab keys from github for those users.check 
# It also does all package updates, installs some needed packages (qemu-guest-agent),
# runs a few misc commands and then reboots the system.
resource "proxmox_virtual_environment_file" "eyedeck_ubuntu_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = <<EOF
#cloud-config
users:
  - name: ubuntu
    groups:
      - sudo
    shell: /bin/bash
    ssh_import_id:
      - "gh:redelman"
      - "gh:eyedeck"
    sudo: ALL=(ALL) NOPASSWD:ALL
  - name: redelman
    groups:
      - sudo
    shell: /bin/bash
    ssh_import_id:
      - "gh:redelman"
    sudo: ALL=(ALL) NOPASSWD:ALL
  - name: eyedeck
    groups:
      - sudo
    shell: /bin/bash
    ssh_import_id:
      - "gh:eyedeck"
    sudo: ALL=(ALL) NOPASSWD:ALL

packages:
  - net-tools
  - qemu-guest-agent

package_upgrade: true

runcmd:
  - timedatectl set-timezone America/Chicago
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  - dpkg -i cloudflared-linux-amd64.deb
  - rm cloudflared-linux-amd64.deb
  - echo "done" > /tmp/vendor-cloud-init-done
  - reboot
EOF

    file_name = "eyedeck-ubuntu-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_23_10_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/releases/23.10/release/ubuntu-23.10-server-cloudimg-amd64.img"
}

// Talos Linux 1.6.4 w/ gvisor, qemu-guest-agent
resource "proxmox_virtual_environment_download_file" "talos_1_6_4_nocloud" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://factory.talos.dev/image/8e8827b5b91420728f8415f3dc200fbf23b425ec07bf27cdc92a676367ee9edf/v1.6.4/nocloud-amd64.iso"
  file_name    = "talos_v1.6.4-nocloud-amd64.iso"
}

