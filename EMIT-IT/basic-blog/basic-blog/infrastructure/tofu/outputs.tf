output "server_ip" {
  value = hcloud_server.client.ipv4_address
}

output "ansible_inventory" {
  value = <<EOT
all:
  hosts:
    ${hcloud_server.client.name}:
      ansible_host: ${hcloud_server.client.ipv4_address}
      ansible_user: deploy
      ansible_ssh_private_key_file: ~/.ssh/your-ci
EOT
}