#!/bin/bash
set -e
IMG=/mnt/c/Development/armbx-build/armbx-raw.img

# Attach loop if not already
LOOP=$(losetup -j "$IMG" | awk -F: '{print $1}' | head -1)
if [ -z "$LOOP" ]; then
    LOOP=$(losetup --find --show --partscan "$IMG")
    sleep 1
fi
echo "Loop: $LOOP"

# Remove the /etc/armbx-backup dir we created during rebrand (not needed in distro)
mkdir -p /mnt/armbx-root
mountpoint -q /mnt/armbx-root || mount "${LOOP}p2" /mnt/armbx-root
if [ -d /mnt/armbx-root/rw/etc/armbx-backup ]; then
    echo "Removing /etc/armbx-backup from overlay"
    rm -rf /mnt/armbx-root/rw/etc/armbx-backup
fi
sync
umount /mnt/armbx-root

echo
echo "=== 1. fsck p2 ==="
e2fsck -f -y "${LOOP}p2" 2>&1 | tail -3

echo
echo "=== 2. Shrink filesystem to minimum ==="
resize2fs -M "${LOOP}p2" 2>&1 | tail -5

echo
echo "=== 3. Query new fs size ==="
BLOCKS=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/Block count/{print $2}' | tr -d ' ')
BLOCKSZ=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/Block size/{print $2}' | tr -d ' ')
FS_BYTES=$((BLOCKS * BLOCKSZ))
echo "fs: $BLOCKS blocks * $BLOCKSZ bytes = $FS_BYTES bytes ($((FS_BYTES/1024/1024)) MB)"

echo
echo "=== 4. Expand fs with 500MB headroom (so growpart on first boot works + user has space) ==="
TARGET_BYTES=$((FS_BYTES + 500*1024*1024))
TARGET_MB=$((TARGET_BYTES / 1024 / 1024))
echo "target: ${TARGET_MB}M"
resize2fs "${LOOP}p2" "${TARGET_MB}M" 2>&1 | tail -3

# Re-query
BLOCKS=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/Block count/{print $2}' | tr -d ' ')
BLOCKSZ=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/Block size/{print $2}' | tr -d ' ')
NEW_FS_BYTES=$((BLOCKS * BLOCKSZ))
echo "fs now: $NEW_FS_BYTES bytes ($((NEW_FS_BYTES/1024/1024)) MB)"

echo
echo "=== 5. Current partition table ==="
sfdisk -d "$LOOP"
echo

echo "=== 6. Resize partition 2 (sfdisk) ==="
P1_START=$(sfdisk -d "$LOOP" | awk '/\sp1\s|loop[0-9]+p1\s/{for(i=1;i<=NF;i++) if($i=="start=") print $(i+1)}' | tr -d ',')
P2_START=$(sfdisk -d "$LOOP" | awk '/p2 /{for(i=1;i<=NF;i++) if($i=="start=") print $(i+1)}' | tr -d ',')
echo "p2 starts at sector: $P2_START"

# New p2 size in sectors (512 bytes each) with 50MB extra margin for safety
P2_SIZE_SECTORS=$(( (NEW_FS_BYTES + 50*1024*1024) / 512 ))
echo "new p2 size: $P2_SIZE_SECTORS sectors ($((P2_SIZE_SECTORS*512/1024/1024)) MB)"

# Rewrite partition table with new p2 size
sfdisk -d "$LOOP" > /tmp/ptable.orig
cat /tmp/ptable.orig
echo "---"
# Edit: replace p2 size
sed -E "s|(${LOOP}p2 : start= *${P2_START}, size= *)[0-9]+|\1${P2_SIZE_SECTORS}|" /tmp/ptable.orig > /tmp/ptable.new
cat /tmp/ptable.new
echo "---"
sfdisk --no-reread "$LOOP" < /tmp/ptable.new
partprobe "$LOOP" 2>/dev/null || true
sleep 1

echo
echo "=== 7. New partition table ==="
sfdisk -d "$LOOP"

echo
echo "=== 8. Compute truncate target ==="
# End of p2 in bytes = (P2_START + P2_SIZE_SECTORS) * 512
END_BYTES=$(( (P2_START + P2_SIZE_SECTORS) * 512 ))
echo "truncating .img to $END_BYTES bytes ($((END_BYTES/1024/1024)) MB)"

echo
echo "=== 9. Detach loop ==="
losetup -d "$LOOP"

echo
echo "=== 10. Truncate .img ==="
truncate -s "$END_BYTES" "$IMG"
ls -la "$IMG"
echo "size: $(stat -c%s "$IMG") bytes ($(( $(stat -c%s "$IMG") / 1024 / 1024 )) MB)"

echo
echo "=== 11. Re-verify shrunk .img ==="
LOOP2=$(losetup --find --show --partscan "$IMG")
echo "attached: $LOOP2"
sleep 1
lsblk "$LOOP2"
e2fsck -n -f "${LOOP2}p2" 2>&1 | tail -3
losetup -d "$LOOP2"

echo
echo "=== DONE. Shrunk .img ready. ==="
