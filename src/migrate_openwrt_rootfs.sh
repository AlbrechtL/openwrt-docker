#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

FILE=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img

# Migrate settings from old OpenWrt version to new one
# if [ -f /storage/old_version ]; then
#   OLD_VERSION_SQUASHFS_COMBINED=`cat /storage/old_version`

#   info "Migrate settings from $OLD_VERSION_SQUASHFS_COMBINED to squashfs-combined-${OPENWRT_IMAGE_ID}.img."
  
#   mount /storage/$OLD_VERSION_SQUASHFS_COMBINED /mnt
#   chroot /mnt/ mkdir -p /var/lock
#   chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
#   mv /mnt/tmp/openwrt_config.tar.gz  /storage/config-`basename $OLD_VERSION_SQUASHFS_COMBINED .img`.tar.gz
#   umount /mnt

#   # Put config backup to new squashfs-combined
#   mount $FILE /mnt
#   mkdir -p /mnt/root/backup
#   cp /storage/config-`basename $OLD_VERSION_SQUASHFS_COMBINED .img`.tar.gz /mnt/root/backup/config.tar.gz
#   chroot /mnt/ mkdir -p /var/lock
#   chroot /mnt /sbin/sysupgrade -r /root/backup/config.tar.gz
#   umount /mnt

#   # Finally remove old squashfs-combined and old files
#   rm /storage/$OLD_VERSION_SQUASHFS_COMBINED
#   rm /storage/old_version
#   rm /storage/config-`basename $OLD_VERSION_SQUASHFS_COMBINED .img`.tar.gz
# else
#   info "squashfs-combined-${OPENWRT_IMAGE_ID}.img is up to date. Nothing to do."
# fi
