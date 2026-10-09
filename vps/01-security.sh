set -e

###############################################
# FASE 1: Security hardening
###############################################
echo "=========================================="
echo "FASE 1: Security hardening"
echo "=========================================="

echo
echo "=== 1.1 Install UFW + fail2ban + unattended-upgrades ==="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ufw fail2ban unattended-upgrades apt-listchanges 2>&1 | tail -3

echo
echo "=== 1.2 Configure UFW ==="
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
# SSH from everywhere (we need remote access)
sudo ufw allow 22/tcp comment 'SSH'
# Allow local LAN (adjust subnet if yours differs)
sudo ufw allow from 192.168.0.0/16 comment 'Local LAN'
# Allow Tailscale network
sudo ufw allow in on tailscale0 comment 'Tailscale'
# Docker containers: we'll expose via Cloudflare Tunnel later, no direct public port
# But allow 80/443 if user wants local hosting (comment out if not needed)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
sudo ufw status verbose

echo
echo "=== 1.3 Configure fail2ban (SSH jail) ==="
sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd
destemail = root@localhost
sender = root@localhost
# Skip Tailscale + LAN
ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16 100.64.0.0/10

[sshd]
enabled = true
port = ssh
mode = aggressive

[sshd-ddos]
enabled = false
EOF
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
sleep 2
sudo fail2ban-client status
sudo fail2ban-client status sshd 2>&1 | head -5

echo
echo "=== 1.4 Enable unattended-upgrades ==="
sudo dpkg-reconfigure -plow unattended-upgrades 2>&1 || true
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
# Only security updates (not full upgrade) - safer for custom OS
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null <<'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Package-Blacklist {
    "linux-image-*";
    "linux-headers-*";
    "docker.io";
    "docker-cli";
    "docker-buildx";
    "containerd";
    "openssh-server";
    "openssh-client";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
EOF
sudo systemctl enable --now unattended-upgrades
sudo systemctl status unattended-upgrades --no-pager | head -5

echo
echo "=== 1.5 Swap tuning (STB 1.88GB RAM) ==="
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-armbx-swap.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.d/99-armbx-swap.conf
sudo sysctl -p /etc/sysctl.d/99-armbx-swap.conf

###############################################
# FASE 2: Container ops stack
###############################################
echo
echo "=========================================="
echo "FASE 2: Container ops stack"
echo "=========================================="

echo
echo "=== 2.1 Create stack directory on USB ==="
sudo mkdir -p /media/armbx-storage/stacks/ops
sudo chown -R 1000:1000 /media/armbx-storage/stacks
cd /media/armbx-storage/stacks/ops

echo
echo "=== 2.2 Write docker-compose.yml ==="
cat > compose.yml <<'COMPOSE'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "127.0.0.1:9000:9000"   # localhost only; akses via tunnel/caddy later
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *   # 04:00 daily
      - WATCHTOWER_NOTIFICATIONS_LEVEL=warn
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro

  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"   # localhost only
    environment:
      - DOZZLE_NO_ANALYTICS=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  portainer_data:
COMPOSE

echo
echo "=== 2.3 Deploy stack ==="
docker compose up -d
sleep 5
docker compose ps

echo
echo "=== 2.4 Test endpoints (local) ==="
curl -s -o /dev/null -w "Portainer: %{http_code}\n" http://127.0.0.1:9000 || true
curl -s -o /dev/null -w "Dozzle:    %{http_code}\n" http://127.0.0.1:8080 || true

echo
echo "=========================================="
echo "Phase 1 + 2 DONE"
echo "=========================================="
echo "- UFW: default deny inbound, allow SSH/80/443/LAN/Tailscale"
echo "- Fail2ban: active, SSH jail"
echo "- Unattended-upgrades: security-only, kernel + docker + ssh excluded"
echo "- Portainer: http://127.0.0.1:9000 (akses via Tailscale: http://bx:9000 ← SSH tunnel manually)"
echo "- Dozzle:    http://127.0.0.1:8080"
echo "- Watchtower: scheduled daily at 04:00 WIB"
echo ""
echo "Portainer first-login: buka http://bx:9000 via SSH tunnel OR tunggu Fase 4 Cloudflare Tunnel."
echo ""
echo "Phase 3 next: Netdata + Uptime Kuma. Say 'lanjut fase 3' to continue."
