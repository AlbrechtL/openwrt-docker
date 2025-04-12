#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

# Check if squashfs-combined is in volume
FILE=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img
if [[ ($DISABLE_OPENWRT_AUTO_UPGRADE != "true") ||  (! -f /storage/current_version) ]]; then
  if [ -f "$FILE" ]; then
      info "$FILE exists. Nothing to do."
  else
      info "$FILE does not exist. Copying squashfs-combined-${OPENWRT_VERSION}.img to storage ..."
      cp /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz /storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img.gz
      gzip -d /storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img.gz

      # Check if IMAGE_SIZE_ON_INIT is set
      if [[ -n "$IMAGE_SIZE_ON_INIT" ]]; then
          # Check if IMAGE_SIZE_ON_INIT is greater than 511
          if [[ "$IMAGE_SIZE_ON_INIT" -gt 511 ]]; then
              info "Resize OpenWrt to $IMAGE_SIZE_ON_INIT MB"
              dd if=/dev/zero of="/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img" seek="$IMAGE_SIZE_ON_INIT" obs=1MB count=0
          else
              error "Error: IMAGE_SIZE_ON_INIT must be greater than 511."
              rm /storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img
              exit 1
          fi
      fi

      if [ -f "/storage/current_version" ]; then
        mv /storage/current_version /storage/old_version
      fi

      touch /storage/current_version
      echo "squashfs-combined-${OPENWRT_IMAGE_ID}.img" > /storage/current_version
  fi
else
  FILE=$(cat /storage/current_version)
  info "OpenWrt upgrade check is disabled. Using "$FILE"."
fi
