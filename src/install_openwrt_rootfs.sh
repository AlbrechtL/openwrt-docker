#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

# Check if rootfs is in volume
FILE=/storage/rootfs-${OPENWRT_VERSION}.img
if [ -f "$FILE" ]; then
    info "$FILE exists. Nothing to do."
else 
    info "$FILE does not exist. Copying rootfs-${OPENWRT_VERSION}.img to storage ..."
    cp /var/vm/rootfs-${OPENWRT_VERSION}.img.gz /storage/rootfs-${OPENWRT_VERSION}.img.gz
    gzip -d /storage/rootfs-${OPENWRT_VERSION}.img.gz
    
    info "Inject some additional files into the image"
    mount /storage/rootfs-${OPENWRT_VERSION}.img /mnt
    # mount -o offset=$((512*262656)) /storage/disk.img /mnt # combined image ext4 partition starts at offset 262656
    chmod +x /var/vm/openwrt_additional/bin/*
    cp /var/vm/openwrt_additional/bin/* /mnt/usr/bin/
    umount /mnt

    if [ -f "/storage/current_version" ]; then
      mv /storage/current_version /storage/old_version
    fi

    touch /storage/current_version
    echo "rootfs-${OPENWRT_VERSION}.img" > /storage/current_version
fi
