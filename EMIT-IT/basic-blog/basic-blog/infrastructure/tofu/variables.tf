variable "client" {
  description = "Client name (used for VM and namespace)"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key string"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx21"
}

variable "location" {
  description = "Hetzner location (fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}

variable "agent_count" {
  description = "Number of agent nodes to provision for the k3s cluster"
  type        = number
  default     = 2
}
