#!/bin/bash
#
# mount_openwrt_squashfs_combined.sh - Mounts openwrt-armsr-armv8-generic-squashfs-combined.img 
# or openwrt-x86-64-generic-squashfs-combined.img filesystem images
#
# Copyright Albrecht Lohofener 2024 <albrechtloh@gmx.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Function to display the help page
show_help() {
  echo "Usage: $(basename "$0") <image> <arch>"
  echo
  echo "Mount OpenWrt filesystem images. Currently the following images are supported:"
  echo "- aarch64 (arm64): openwrt-armsr-armv8-generic-squashfs-combined.img"
  echo "- x86_64: openwrt-x86-64-generic-squashfs-combined.img"
  echo
  echo "Arguments:"
  echo "  <image>   Filesystem image"
  echo
  echo "Options:"
  echo "  -u, --umount  Unmounts a previous mounted image"
  echo "  -o, --offsets Give offsets (comma-separated <squashfs>,<ext4 or f2fs>)"
  echo "  -h, --help    Display this help message"
  echo
  echo "Example:"
  echo "mount_openwrt_squashfs_combiened.sh openwrt-x86-64-generic-squashfs-combined.img x86_64"
}

# Function to find the squashfs file system start offset from a OpenWrt given file
find_squashfs_offset() {
  local IMAGE_FILE="$1"
  
  # Use fdisk to find the squashfs partition
  local squashfs_start_sectors=`fdisk -l "$IMAGE_FILE" | awk '/^.*squashfs-combined.*.img2/ {print $2}'` # use the 4th ouput as sectors

  if [ -z "$squashfs_start_sectors" ]; then
    echo >&2 "No squashfs-combined*.img2 found"
    return 1
  fi

  local squashfs_offset=$(( squashfs_start_sectors * 512 )) # Each sector has 512 bytes

  echo >&2 "squashfs file system start at offset 0x$(printf '%x' "$squashfs_offset") ($squashfs_offset)"

  echo $squashfs_offset
}

# Function to find the ext4 file system start offset from a OpenWrt given file
find_ext4_offset() {
  local IMAGE_FILE="$1"
  local SQUASHFS_OFFSET="$2"

  # Define the search boundary (in bytes)
  local SQUASHFS_SIZE_APPROX=4000000  # This is the size assumption of squashfs file system that is located before the f2fs
  #local BYTE_COUNT_EXT4_VOLUME_NAME=1000000
  local SEARCH_BOUNDARY=200  # This is the search boundary for extracting data before and after 'rootfs_data'
  local EXT4_MAGIC_KEY="\x53\xef"  # This is the magic key identifying the ext4 file system (as hex string)
  local ROOTFS_PATTERN="rootfs_data"  # This is the pattern we are searching for in the file

  # Step 1: Find the OFFSET of the first occurrence of 'rootfs_data'
  local OFFSET=$(tail -c +$((SQUASHFS_OFFSET + SQUASHFS_SIZE_APPROX)) "$IMAGE_FILE" | grep -obam 1 "$ROOTFS_PATTERN" | awk -F':' '{print $1}')
  #local OFFSET=$(dd if="$IMAGE_FILE" bs=1 skip="$((SQUASHFS_OFFSET + SQUASHFS_SIZE_APPROX))" count="$BYTE_COUNT_EXT4_VOLUME_NAME" 2>/dev/null | grep -obam 1 "$ROOTFS_PATTERN" | awk -F':' '{print $1}')
  if [ -n "$OFFSET" ]; then
    OFFSET=$((OFFSET + SQUASHFS_OFFSET + SQUASHFS_SIZE_APPROX))
  else
    echo >&2 "'$ROOTFS_PATTERN' not found in the file."
    return 1
  fi

  #local OFFSET=`grep -obam 1 "$ROOTFS_PATTERN" "$IMAGE_FILE" | awk -F':' '{print $1}'`

  if [ -z "$OFFSET" ]; then
    echo >&2 "'$ROOTFS_PATTERN' not found in the file."
    return 1
  fi

  # Output OFFSET in hexadecimal format
  echo >&2 "Found volume name '$ROOTFS_PATTERN' at offset: 0x$(printf '%x' "$OFFSET") ($OFFSET)"

  # Step 2: Use dd to extract the bytes and search for the EXT4_MAGIC_KEY
  # Extract the byte offset from the grep result (this is relative to the start of the dd block)
  local offset_in_block=`dd if="$IMAGE_FILE" bs=1 skip=$((OFFSET - SEARCH_BOUNDARY)) count=$SEARCH_BOUNDARY 2>/dev/null | 
    LANG=C grep -obUaPm 1 $EXT4_MAGIC_KEY | cut -d: -f1`

  if [ -z "$offset_in_block" ]; then
    echo >&2 "ext4 magic key not found in the file."
    return 1
  fi

  local actual_offset=$((offset_in_block + OFFSET - SEARCH_BOUNDARY)) # Adjust the offset to the actual position in the original file
  local ext4_start_offset=$((actual_offset - 1080))  # Subtract 1080 bytes from the found offset. ext4 is starting 1080 before 0x53ef

  # Show the adjusted actual_offset
  #echo >&2 "Offset in dd block: 0x$(printf '%x' "$offset_in_block")"
  echo >&2 "Found ext4 magic key '$EXT4_MAGIC_KEY' at offset: 0x$(printf '%x' "$actual_offset") ($actual_offset)"
  echo >&2 "ext4 file system start at offset: 0x$(printf '%x' "$ext4_start_offset") ($ext4_start_offset)"

  echo $ext4_start_offset
}

# Function to find the ext4 file system start offset from a OpenWrt given file
find_f2fs_offset() {
  local IMAGE_FILE="$1"
  local SQUASHFS_OFFSET="$2"

  # Define the search boundary (in bytes)
  local SQUASHFS_SIZE_APPROX=4000000  # This is the size assumption of squashfs file system that is located before the f2fs
  local F2FS_MAX_SEARCH_BYTES=100000  # This is number of bytes to search for the f2fs magic key
  local F2FS_MAGIC_KEY="\x10\x20\xf5\xf2"  # This is the magic key identifying the ext4 file system (as hex string)

  local offset_in_block=`dd if="$IMAGE_FILE" bs=1 skip=$((SQUASHFS_OFFSET + SQUASHFS_SIZE_APPROX)) count=$F2FS_MAX_SEARCH_BYTES 2>/dev/null | \
    LANG=C grep -obUaPm 1 "$F2FS_MAGIC_KEY" | cut -d: -f1`

  if [ -z "$offset_in_block" ]; then
    echo >&2 "f2fs magic key not found in the file."
    return 1
  fi

  local actual_offset=$((offset_in_block + SQUASHFS_OFFSET + SQUASHFS_SIZE_APPROX)) # Adjust the offset to the actual position in the original file
  local f2fs_start_offset=$((actual_offset - 1024))  # Subtract 1024 bytes from the found offset. f2fs is starting 1024 before 0x1020f5f2

  echo >&2 "Found f2fs magic key '$F2FS_MAGIC_KEY' at offset: 0x$(printf '%x' "$actual_offset") ($actual_offset)"
  echo >&2 "f2fs file system start at offset: 0x$(printf '%x' "$f2fs_start_offset") ($f2fs_start_offset)"

  echo $f2fs_start_offset
}

# Function to find and return the squashfs and write filesystem offsets
find_offsets() {
  IMAGE_FILE="$1"

  echo >&2 "Start finding file system offsets in file '"$IMAGE_FILE"' ..."

  # 1. Find squashfs offset 
  echo >&2 "Try to find squashfs writable filesystem"
  squashfs_start_offset=$(find_squashfs_offset "$IMAGE_FILE")

   if [ $? -eq 1 ]; then
    echo >&2 "No squashfs filesystem found"
    return 1
  fi

  # 2. Try to find ext4 offset (most likely on x86_64 image and on some armsr images)
  echo >&2 "Try to find ext4 writable filesystem"
  start_offset=$(find_ext4_offset "$IMAGE_FILE" "$squashfs_start_offset")

  if [ $? -eq 1 ]; then
    echo >&2 "Try to find f2fs writable filesystem"
    start_offset=$(find_f2fs_offset "$IMAGE_FILE" "$squashfs_start_offset")
  fi

  if [ $? -eq 1 ]; then
    echo >&2 "No writable filesystem found"
    return 1
  fi

  echo "$squashfs_start_offset,$start_offset"
  return 0
}

umount_squashfs_combined_image() {
  umount /mnt/overlay
  umount /mnt/rom
  umount /mnt/dev
  umount /mnt
  umount /tmp/userdata_dir
  umount /tmp/squashfs_dir
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# Check for umount option
if [[ "$1" == "-u" || "$1" == "--umount" ]]; then
  umount_squashfs_combined_image
  exit 0
fi

# Check for give offsets option
if [[ "$1" == "-o" || "$1" == "--offsets" ]]; then
  IMAGE_FILE="$2"
  find_offsets $IMAGE_FILE
  if [ $? -eq 1 ]; then
    exit 1
  else
    exit 0
  fi
fi

# Check for the correct number of arguments
if [[ $# -ne 1 ]]; then
  echo "Error: Exactly one arguments are required."
  show_help
  exit 1
fi

# Assign arguments to variables
IMAGE_FILE="$1"

set -Eeuo pipefail

FILESYSTEM_OFFSETS=$(find_offsets $IMAGE_FILE)

squashfs_start_offset=$(echo $FILESYSTEM_OFFSETS | cut -d',' -f1)
writable_start_offset=$(echo $FILESYSTEM_OFFSETS | cut -d',' -f2)

squashfs_start_offset=$(find_squashfs_offset "$IMAGE_FILE")

mkdir -p /tmp/squashfs_dir
mkdir -p /tmp/userdata_dir

# Mount lower and upper file systems
mount -o offset="$squashfs_start_offset",sizelimit=$((writable_start_offset-squashfs_start_offset)) "$IMAGE_FILE" /tmp/squashfs_dir
mount -o offset="$writable_start_offset" "$IMAGE_FILE" /tmp/userdata_dir

# Mount overlay
mount -t overlay -o lowerdir=/tmp/squashfs_dir,upperdir=/tmp/userdata_dir/upper,workdir=/tmp/userdata_dir/work overlay /mnt

# Do some bind mounts that OpenWrt tools like sysupgrade are working properly
mount -o bind /tmp/userdata_dir /mnt/overlay/
mount -o bind /tmp/squashfs_dir /mnt/rom/
mount -o bind /dev /mnt/dev

echo "Image $IMAGE_FILE successfully mounted to /mnt"
