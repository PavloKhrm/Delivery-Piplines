export function buildUserData({ user, repo, branch }) {
    return `#cloud-config
  package_update: true
  package_upgrade: true
  packages:
    - ca-certificates
    - curl
    - gnupg
    - wget
  
  runcmd:
    - bash -lc 'install -m 0755 -d /etc/apt/keyrings'
    - bash -lc 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    - bash -lc 'chmod a+r /etc/apt/keyrings/docker.gpg'
    - bash -lc 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list'
    - bash -lc 'apt-get update -y'
    - bash -lc 'DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
    - bash -lc 'systemctl enable --now docker'
  
    # клонируем репозиторий и переносим всю папку site
    - bash -lc 'mkdir -p /srv && cd /srv'
    - bash -lc 'curl -L https://github.com/${user}/${repo}/archive/refs/heads/${branch}.tar.gz | tar -xz'
    - bash -lc 'mv ${repo}-${branch}/site /srv/site'
  
    # создаём .env, если его нет
    - bash -lc '[ -f /srv/site/.env ] || cp /srv/site/.env.example /srv/site/.env || true'
  
    # поднимаем контейнеры
    - bash -lc 'cd /srv/site && docker compose up -d --build'
  
  final_message: "cloud-init finished — app should be on port 80."
  `;
  }
  