export function buildUserDataDocker({ user, repo, branch }) {
  return `#cloud-config
package_update: true
package_upgrade: true
packages: [ca-certificates, curl, gnupg, wget]
runcmd:
  - bash -lc 'install -m 0755 -d /etc/apt/keyrings'
  - bash -lc 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  - bash -lc 'chmod a+r /etc/apt/keyrings/docker.gpg'
  - bash -lc 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list'
  - bash -lc 'apt-get update -y'
  - bash -lc 'DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
  - bash -lc 'systemctl enable --now docker'
  - bash -lc 'mkdir -p /srv && cd /srv'
  - bash -lc 'curl -L https://github.com/${user}/${repo}/archive/refs/heads/${branch}.tar.gz | tar -xz'
  - bash -lc 'mv ${repo}-${branch}/site /srv/site'
  - bash -lc '[ -f /srv/site/.env ] || cp /srv/site/.env.example /srv/site/.env || true'
  - bash -lc 'cd /srv/site && docker compose up -d --build'
final_message: "cloud-init finished"
`;
}

export function buildUserDataK3sServer() {
  return `#cloud-config
package_update: true
package_upgrade: true
runcmd:
  - bash -lc 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -'
final_message: "k3s server ready"
`;
}

export function buildUserDataK3sAgent({ masterIp, token, nodeName }) {
  return `#cloud-config
package_update: true
package_upgrade: true
write_files:
  - path: /root/k3s.env
    permissions: '0644'
    content: |
      K3S_URL=https://${masterIp}:6443
      K3S_TOKEN=${token}
      INSTALL_K3S_EXEC="--node-name ${nodeName}"
runcmd:
  - bash -lc 'set -a; . /root/k3s.env; set +a; curl -sfL https://get.k3s.io | sh -'
final_message: "k3s agent joined"
`;
}
