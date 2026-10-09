#!/bin/bash
set -e
IMG=/mnt/c/Development/armbx-build/armbx-full.img
ASSETS=/mnt/c/Development/armbx-build/assets

LOOP=$(losetup -j "$IMG" | awk -F: '{print $1}' | head -1)
if [ -z "$LOOP" ]; then
    LOOP=$(losetup --find --show --partscan "$IMG")
    sleep 1
fi
echo "Loop: $LOOP"
e2fsck -f -y "${LOOP}p2" 2>&1 | tail -2

mkdir -p /mnt/v152
mountpoint -q /mnt/v152 && umount /mnt/v152
mount "${LOOP}p2" /mnt/v152
OL=/mnt/v152/rw

echo
echo "=== Update firstboot v4 with always-try-growpart ==="
install -m 755 "$ASSETS/firstboot-v4.sh" "$OL/usr/local/sbin/armbx-firstboot"
head -3 "$OL/usr/local/sbin/armbx-firstboot"

echo
echo "=== Clear firstboot STATE so new script runs ==="
rm -f "$OL/var/lib/armbx-firstboot.done"
rm -f "$OL/var/log/armbx-firstboot.log"

sync
umount /mnt/v152
e2fsck -f -y "${LOOP}p2" 2>&1 | tail -2
losetup -d "$LOOP"

echo
echo "=== Recompress v1.5.2 ==="
cd /mnt/c/Development/armbx-build
rm -f armbx-os-1.0.img armbx-os-1.0.img.xz armbx-os-1.0.img.xz.sha256
cp "$IMG" armbx-os-1.0.img
echo "compressing..."
xz -T 0 -6 -k --force armbx-os-1.0.img
sha256sum armbx-os-1.0.img.xz > armbx-os-1.0.img.xz.sha256
ls -la armbx-os-1.0.img.xz*
cat armbx-os-1.0.img.xz.sha256
echo "DONE v1.5.2"
