terraform {
  required_providers {
    hcloud = {
      source  = "registry.terraform.io/hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Dynamically register SSH key in Hetzner for this client
resource "hcloud_ssh_key" "deploy" {
  name       = "${var.client}-deploy-key"
  public_key = var.ssh_public_key
}

# Single VM per client (Ubuntu + cloud-init prereqs)
resource "hcloud_server" "client" {
  name        = "k3s-${var.client}"
  server_type = var.server_type   # e.g. "cpx21"
  image       = "ubuntu-22.04"
  location    = var.location      # e.g. "nbg1"
  ssh_keys    = [hcloud_ssh_key.deploy.name]

  user_data = <<-CLOUD
  #cloud-config
  package_update: true
  packages:
    - curl
    - ca-certificates
    - apt-transport-https
  users:
    - name: deploy
      groups: [ sudo ]
      sudo: "ALL=(ALL) NOPASSWD:ALL"
      shell: /bin/bash
      ssh_authorized_keys:
        - ${var.ssh_public_key}
  runcmd:
    - sysctl -w net.ipv4.ip_forward=1
  CLOUD
}
