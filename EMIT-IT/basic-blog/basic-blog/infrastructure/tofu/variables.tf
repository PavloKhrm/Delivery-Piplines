# ───────────────────────────────────────────────
# VARIABLES FOR HETZNER K3s PROVISIONING
# ───────────────────────────────────────────────

# Client short name (used for resource names, namespaces, and SSH key tags)
variable "client" {
  description = "Client identifier (used for VM names, SSH keys, and namespaces)"
  type        = string
}

# Hetzner API token (set via Bitbucket variable HCLOUD_TOKEN)
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

# SSH public key (used for Ansible user 'deploy')
variable "ssh_public_key" {
  description = "Public SSH key content for the deploy user"
  type        = string
}

# VM type (Hetzner Cloud server size)
variable "server_type" {
  description = "Hetzner server type (e.g., cpx11, cpx21, cpx31)"
  type        = string
  default     = "cpx21"
}

# Region / datacenter
variable "location" {
  description = "Hetzner location (fsn1 = Falkenstein, nbg1 = Nuremberg, hel1 = Helsinki)"
  type        = string
  default     = "fsn1"
}

# Number of agent nodes
variable "agent_count" {
  description = "Number of worker (agent) nodes for the K3s cluster"
  type        = number
  default     = 2
}
