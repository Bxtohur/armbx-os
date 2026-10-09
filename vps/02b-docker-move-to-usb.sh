#!/bin/bash
set -e

echo "=== 1. Clean + remount USB with proper label path ==="
sudo umount /dev/sda1 2>/dev/null || true
sudo rmdir /media/sda1 /media/sdb1 /media/armbx-storage 2>/dev/null || true
sudo udevadm trigger --action=add /dev/sda1
sleep 2
mount | grep armbx-storage
df -h /media/armbx-storage

echo
echo "=== 2. Stop docker + containerd ==="
sudo systemctl stop docker.socket docker containerd
systemctl is-active docker containerd

echo
echo "=== 3. Rsync /var/lib/docker to USB ==="
sudo mkdir -p /media/armbx-storage/docker
sudo rsync -a --info=progress2 /var/lib/docker/ /media/armbx-storage/docker/ 2>&1 | tail -5

echo
echo "=== 4. Backup old data + write daemon.json ==="
sudo mv /var/lib/docker /var/lib/docker.bak
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "data-root": "/media/armbx-storage/docker",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
cat /etc/docker/daemon.json

echo
echo "=== 5. Make docker service wait for USB mount ==="
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/wait-for-usb.conf >/dev/null <<'EOF'
[Unit]
RequiresMountsFor=/media/armbx-storage
EOF
sudo systemctl daemon-reload

echo
echo "=== 6. Start docker ==="
sudo systemctl start docker
sleep 2
systemctl is-active docker

echo
echo "=== 7. Verify new state ==="
docker info 2>&1 | grep -E 'Server Version|Storage Driver|Root Dir|Backing Filesystem'
echo "--- disk root ---"
df -h /var/lib/docker 2>/dev/null || df -h /media/armbx-storage/docker

echo
echo "=== 8. Test hello-world ==="
docker run --rm hello-world 2>&1 | head -5

echo
echo "=== 9. Cleanup NOPASSWD ==="
sudo rm -f /etc/sudoers.d/99-bx-tmp
ls /etc/sudoers.d/

echo
echo "=== DONE ==="
echo "Old data preserved at /var/lib/docker.bak (hapus manual kalau sudah yakin: sudo rm -rf /var/lib/docker.bak)"
