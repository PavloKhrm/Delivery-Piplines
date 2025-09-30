# Master IP (for quick reference)
output "master_ip" {
  value = hcloud_server.master[0].ipv4_address
}

# Agent IPs (list)
output "agent_ips" {
  value = [for s in hcloud_server.agents : s.ipv4_address]
}

# Full Ansible inventory in YAML
output "ansible_inventory" {
  value = yamlencode({
    all = {
      children = {
        k3s_master = {
          hosts = {
            for i, s in hcloud_server.master :
            "master${i+1}" => {
              ansible_host                 = s.ipv4_address
              ansible_user                 = "deploy"
              ansible_ssh_private_key_file = "~/.ssh/your-ci"
            }
          }
        }
        k3s_agents = {
          hosts = {
            for i, s in hcloud_server.agents :
            "agent${i+1}" => {
              ansible_host                 = s.ipv4_address
              ansible_user                 = "deploy"
              ansible_ssh_private_key_file = "~/.ssh/your-ci"
            }
          }
        }
      }
    }
  })
}
