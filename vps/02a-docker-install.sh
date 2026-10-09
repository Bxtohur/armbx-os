#!/bin/bash
set -e

echo "=== Current state ==="
mount | grep -E 'sda|sdb|/media' || echo "(no USB mounted)"

echo
echo "=== 1. apt update ==="
sudo apt-get update 2>&1 | tail -3

echo
echo "=== 2. Install docker.io + compose plugin + buildx ==="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker.io docker-compose-v2 docker-buildx \
    2>&1 | tail -5

echo
echo "=== 3. apt-mark hold ==="
sudo apt-mark hold docker.io docker-compose-v2 docker-buildx containerd 2>&1

echo
echo "=== 4. Enable + start docker ==="
sudo systemctl enable --now docker
systemctl is-active docker
systemctl is-enabled docker

echo
echo "=== 5. Verify docker version ==="
docker --version
docker compose version 2>&1 | head -1

echo
echo "=== 6. Test hello-world ==="
docker run --rm hello-world 2>&1 | head -20

echo
echo "=== 7. Set up daemon.json for USB storage fallback ==="
# If /media/armbx-storage is mountpoint, use it. Else keep /var/lib/docker on SD.
if mountpoint -q /media/armbx-storage 2>/dev/null; then
    echo "USB mounted — would configure data-root. (Skipping for now to avoid downtime; manual later)"
else
    echo "USB not mounted. Keeping /var/lib/docker on SD. To move later:"
    echo "  1. Plug USB (ext4-formatted labeled armbx-storage)"
    echo "  2. sudo systemctl stop docker"
    echo "  3. sudo rsync -a /var/lib/docker/ /media/armbx-storage/docker/"
    echo "  4. echo '{\"data-root\":\"/media/armbx-storage/docker\"}' | sudo tee /etc/docker/daemon.json"
    echo "  5. sudo mv /var/lib/docker /var/lib/docker.bak && sudo systemctl start docker"
fi

echo
echo "=== 8. Docker info ==="
docker info 2>&1 | grep -E 'Server Version|Storage Driver|Logging|Root Dir|Kernel|OS|Arch|CPUs|Memory' | head -15

echo
echo "=== 9. Remove NOPASSWD-all temp sudoers ==="
sudo rm -f /etc/sudoers.d/99-bx-tmp
echo "sudoers.d now:"
ls /etc/sudoers.d/

echo
echo "=== DONE ==="
echo "User bx bisa langsung pakai 'docker ps', 'docker compose up', dsb. (sudah di group docker)"
