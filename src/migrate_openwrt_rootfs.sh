#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

# Function to find the squashfs file system start offset from a OpenWrt given file
find_squashfs_offset() {
  local IMAGE_FILE="$1"
  echo >&2 "Start finding start of squashfs file system in file '"$IMAGE_FILE"' ..."

  # Use fdisk to find the squashfs partition
  local squashfs_start_sectors=`fdisk -l "$IMAGE_FILE" | awk '/^.*squashfs-combined.*.img2/ {print $4}'` # use the 4th ouput as sectors

  if [ -z "$squashfs_start_sectors" ]; then
    echo >&2 "No squashfs-combined*.img2 found"
    return 1
  fi

  local squashfs_offset=$(( squashfs_start_sectors * 512 )) # Each sector has 512 bytes

  echo >&2 "squashfs file system start at offset 0x$(printf '%x' "$squashfs_offset")"

  echo $squashfs_offset
}

# Function to find the ext4 file system start offset from a OpenWrt given file
find_ext4_offset() {
  local IMAGE_FILE="$1"
  echo >&2 "Start finding start of ext4 file system in file '$IMAGE_FILE' ..."

  # Define the search boundary (in bytes)
  local SEARCH_BOUNDARY=200  # This is the search boundary for extracting data before and after 'rootfs_data'
  local EXT4_MAGIC_KEY="\x53\xef"  # This is the magic key identifying the ext4 file system (as hex string)
  local ROOTFS_PATTERN="rootfs_data"  # This is the pattern we are searching for in the file

  # Step 1: Find the OFFSET of the first occurrence of 'rootfs_data'
  local OFFSET=`grep -obam 1 "$ROOTFS_PATTERN" "$IMAGE_FILE" | awk -F':' '{print $1}'`

  if [ -z "$OFFSET" ]; then
    echo >&2 "'$ROOTFS_PATTERN' not found in the file."
    return 1
  fi

  # Output OFFSET in hexadecimal format
  echo >&2 "Found volume name '$ROOTFS_PATTERN' at offset: 0x$(printf '%x' "$OFFSET")"

  # Step 2: Use dd to extract the bytes and search for the EXT4_MAGIC_KEY
  # Extract the byte offset from the grep result (this is relative to the start of the dd block)
  local offset_in_block=`dd if="$IMAGE_FILE" bs=1 skip=$((OFFSET - SEARCH_BOUNDARY)) count=$SEARCH_BOUNDARY 2>/dev/null | 
    LANG=C grep -obUaPm 1 $EXT4_MAGIC_KEY | cut -d: -f1`

  if [ -z "$offset_in_block" ]; then
    echo >&2 "ext4 magic key not found in the file."
    return 1
  fi

  actual_offset=$((offset_in_block + OFFSET - SEARCH_BOUNDARY)) # Adjust the offset to the actual position in the original file
  local ext4_start_offset=$((actual_offset - 1080))  # Subtract 1080 bytes from the found offset. ext4 is starting 1080 before 0x53ef

  # Show the adjusted actual_offset
  #echo >&2 "Offset in dd block: 0x$(printf '%x' "$offset_in_block")"
  echo >&2 "Found ext4 magic key '$EXT4_MAGIC_KEY' at offset: 0x$(printf '%x' "$actual_offset")"
  echo >&2 "ext4 file system start at offset: 0x$(printf '%x' "$ext4_start_offset")"

  echo $ext4_start_offset
}

mount_squashfs_combined_image() {
  local IMAGE_FILE="$1"

  squashfs_start_offset=$(find_squashfs_offset "$IMAGE_FILE")
  ext4_start_offset=$(find_ext4_offset "$IMAGE_FILE")
  
  mkdir -p /tmp/squashfs_dir
  mkdir -p /tmp/ext4_dir

  mount -o offset="$squashfs_start_offset" "$IMAGE_FILE" /tmp/squashfs_dir
  mount -o offset="$ext4_start_offset" "$IMAGE_FILE" /tmp/ext4_dir

  mount -t overlay -o lowerdir=/tmp/squashfs_dir,upperdir=/tmp/ext4_dir/upper,workdir=/tmp/ext4_dir/work overlay /mnt
}

umount_squashfs_combined_image() {
  umount /mnt
  umount /tmp/ext4_dir
  umount /tmp/squashfs_dir
}

SQUASHFS_COMBINED=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img

# Migrate settings from old OpenWrt version to new one
if [ -f /storage/old_version ]; then
  OLD_SQUASHFS_COMBINED=`cat /storage/old_version`

  info "Migrate settings from $OLD_SQUASHFS_COMBINED to squashfs-combined-${OPENWRT_IMAGE_ID}.img."

  # Create config backup in previos image
  if [[ $OLD_SQUASHFS_COMBINED == *"rootfs"* ]]; then
      warn "Using rootfs-<UUID>.img images is deprecated!"
      mount /storage/$OLD_SQUASHFS_COMBINED /mnt
      chroot /mnt/ mkdir -p /var/lock
      chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
      mv /mnt/tmp/openwrt_config.tar.gz  /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz
      umount /mnt
  else
      mount_squashfs_combined_image /storage/$OLD_SQUASHFS_COMBINED
      chroot /mnt/ mkdir -p /var/lock
      chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
      mv /mnt/tmp/openwrt_config.tar.gz /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz
      umount_squashfs_combined_image
  fi

  # Put config backup to new squashfs-combined
  mount_squashfs_combined_image $SQUASHFS_COMBINED
  mkdir -p /mnt/root/backup
  cp /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz /mnt/root/backup/config.tar.gz
  chroot /mnt/ mkdir -p /var/lock
  chroot /mnt /sbin/sysupgrade -r /root/backup/config.tar.gz
  umount_squashfs_combined_image 

  # Finally remove old squashfs-combined and old files
  rm /storage/$OLD_SQUASHFS_COMBINED
  rm /storage/old_version
  rm /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz
else
  info "squashfs-combined-${OPENWRT_IMAGE_ID}.img is up to date. Nothing to do."
fi