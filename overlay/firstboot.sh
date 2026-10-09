#!/bin/bash
# ArmBX OS firstboot v4 — regen identity + expand rootfs + protect packages
export DEBIAN_FRONTEND=noninteractive
STATE=/var/lib/armbx-firstboot.done
[ -f "$STATE" ] && exit 0

LOG=/var/log/armbx-firstboot.log
mkdir -p /var/log
exec >>"$LOG" 2>&1
echo "=== $(date) ArmBX OS first-boot v4 ==="

# 1. Regenerate SSH host keys
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    echo "regenerating SSH host keys..."
    ssh-keygen -A
    systemctl restart ssh 2>/dev/null || true
fi

# 2. Regenerate machine-id if empty
if [ ! -s /etc/machine-id ]; then
    echo "regenerating machine-id..."
    rm -f /etc/machine-id
    systemd-machine-id-setup
fi

# 3. Protect critical packages
echo "pinning critical packages..."
apt-mark hold \
    openssh-server openssh-client openssh-sftp-server \
    network-manager systemd systemd-sysv \
    bash coreutils util-linux \
    whiptail ntfs-3g cloud-guest-utils tailscale 2>/dev/null || true
apt-mark manual \
    openssh-server openssh-client network-manager systemd \
    bash coreutils util-linux \
    whiptail ntfs-3g cloud-guest-utils 2>/dev/null || true

# 4. Expand root partition to full SD (always try - no size pre-check)
if [ -b /dev/mmcblk0p2 ]; then
    echo "attempting to grow /dev/mmcblk0p2..."
    echo "  current partition:"
    sfdisk -l /dev/mmcblk0 2>&1 | tail -4
    if command -v growpart >/dev/null; then
        growpart /dev/mmcblk0 2 2>&1 || echo "  growpart returned non-zero (maybe already max)"
    else
        echo "  growpart not found, using embedded sfdisk resize"
        DISK_END=$(( $(blockdev --getsz /dev/mmcblk0) - 1 ))
        P2_START=$(sfdisk -d /dev/mmcblk0 | awk '/mmcblk0p2 /{for(i=1;i<=NF;i++) if($i=="start=") print $(i+1)}' | tr -d ',')
        NEW_SIZE=$(( DISK_END - P2_START ))
        echo ",$NEW_SIZE" | sfdisk --no-reread -N 2 /dev/mmcblk0 2>&1 || echo "  sfdisk failed"
        partprobe /dev/mmcblk0 2>/dev/null || true
    fi
    sleep 2
    echo "  resize2fs:"
    resize2fs /dev/mmcblk0p2 2>&1 || echo "  resize2fs returned non-zero"
    echo "  new state:"
    df -h / 2>&1 | tail -1
fi

touch "$STATE"
systemctl disable armbx-firstboot.service 2>/dev/null || true
echo "=== first-boot complete at $(date) ==="
exit 0
