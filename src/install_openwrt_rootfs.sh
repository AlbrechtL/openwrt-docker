#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

# Check if squashfs-combined is in volume
FILE=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img
if [ -f "$FILE" ]; then
    info "$FILE exists. Nothing to do."
else 
    info "$FILE does not exist. Copying squashfs-combined-${OPENWRT_VERSION}.img to storage ..."
    cp /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz /storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img.gz
    gzip -d /storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img.gz
    
    if [ -f "/storage/current_version" ]; then
      mv /storage/current_version /storage/old_version
    fi

    touch /storage/current_version
    echo "squashfs-combined-${OPENWRT_IMAGE_ID}.img" > /storage/current_version
fi
