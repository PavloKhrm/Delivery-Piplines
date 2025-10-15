terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }

  # Optional: enable this when you set up remote state (recommended)
  # backend "s3" {
  #   bucket         = "emitit-tofu-states"
  #   key            = "hetzner/${var.client}/terraform.tfstate"
  #   region         = "eu-central-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "hcloud" {
  token = var.hcloud_token
}

# ───────────────────────────────────────────────
# RANDOM SUBNET
# ───────────────────────────────────────────────
resource "random_integer" "subnet" {
  min = 10
  max = 200
}

# ───────────────────────────────────────────────
# PRIVATE NETWORK
# ───────────────────────────────────────────────
resource "hcloud_network" "net" {
  name     = "${var.client}-net"
  ip_range = "10.${random_integer.subnet.result}.0.0/16"
}

# ───────────────────────────────────────────────
# FIREWALL (restrict SSH + web ports)
# ───────────────────────────────────────────────
resource "hcloud_firewall" "fw" {
  name = "${var.client}-firewall"

  rule {
    direction       = "in"
    protocol        = "tcp"
    port            = "22"
    source_ips      = ["0.0.0.0/0", "::/0"]
    destination_ips = ["0.0.0.0/0"]
  }

  # Separate HTTP, HTTPS, and K3s API ports
  rule {
    direction       = "in"
    protocol        = "tcp"
    port            = "80"
    source_ips      = ["0.0.0.0/0", "::/0"]
    destination_ips = ["0.0.0.0/0"]
  }

  rule {
    direction       = "in"
    protocol        = "tcp"
    port            = "443"
    source_ips      = ["0.0.0.0/0", "::/0"]
    destination_ips = ["0.0.0.0/0"]
  }

  rule {
    direction       = "in"
    protocol        = "tcp"
    port            = "6443"
    source_ips      = ["0.0.0.0/0", "::/0"]
    destination_ips = ["0.0.0.0/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    source_ips      = ["0.0.0.0/0", "::/0"]
    destination_ips = ["0.0.0.0/0"]
  }
}

# ───────────────────────────────────────────────
# NETWORK SUBNET
# ───────────────────────────────────────────────
resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.net.id
  type         = "server"
  network_zone = "eu-central" # or "eu-central" / "us-east" based on location
  ip_range     = "10.${random_integer.subnet.result}.0.0/24"
}

# ───────────────────────────────────────────────
# SSH KEY
# ───────────────────────────────────────────────
resource "hcloud_ssh_key" "deploy" {
  name       = "${var.client}-deploy-${substr(md5(var.ssh_public_key), 0, 6)}"
  public_key = var.ssh_public_key
}

# ───────────────────────────────────────────────
# MASTER NODE
# ───────────────────────────────────────────────
resource "hcloud_server" "master" {
  depends_on = [hcloud_network_subnet.subnet]
  name         = "k3s-${var.client}-master"
  server_type  = var.server_type   # e.g., "cpx21"
  image        = "ubuntu-22.04"
  location     = var.location      # e.g., "nbg1"
  ssh_keys     = [hcloud_ssh_key.deploy.name]
  firewall_ids = [hcloud_firewall.fw.id]

  network {
    network_id = hcloud_network.net.id
  }

user_data = <<-CLOUD
#cloud-config
package_update: true
users:
  - name: deploy
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${var.ssh_public_key}
runcmd:
  - sysctl -w net.ipv4.ip_forward=1
CLOUD
}

# ───────────────────────────────────────────────
# AGENT NODES
# ───────────────────────────────────────────────
resource "hcloud_server" "agents" {
  depends_on = [hcloud_network_subnet.subnet]
  count        = var.agent_count
  name         = "k3s-${var.client}-agent-${count.index}"
  server_type  = var.server_type
  image        = "ubuntu-22.04"
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.deploy.name]
  firewall_ids = [hcloud_firewall.fw.id]

  network {
    network_id = hcloud_network.net.id
  }

user_data = <<-CLOUD
#cloud-config
package_update: true
users:
  - name: deploy
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${var.ssh_public_key}
CLOUD
}