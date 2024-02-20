#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

FILE=/storage/rootfs-${OPENWRT_VERSION}.img

# Migrate settings from old OpenWrt version to new one
if [ -f /storage/old_version ]; then
  OLD_VERSION_ROOTFS=`cat /storage/old_version`

  info "Migrate settings from $OLD_VERSION_ROOTFS to rootfs-${OPENWRT_VERSION}.img."
  
  mount /storage/$OLD_VERSION_ROOTFS /mnt
  chroot /mnt/ mkdir -p /var/lock
  chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
  mv /mnt/tmp/openwrt_config.tar.gz  /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz
  umount /mnt

  # Put config backup to new rootfs
  mount $FILE /mnt
  mkdir -p /mnt/root/backup
  cp /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz /mnt/root/backup/config.tar.gz
  chroot /mnt/ mkdir -p /var/lock
  chroot /mnt /sbin/sysupgrade -r /root/backup/config.tar.gz
  umount /mnt

  # Finally remove old rootfs and old files
  rm /storage/$OLD_VERSION_ROOTFS
  rm /storage/old_version
  rm /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz
else
  info "rootfs-${OPENWRT_VERSION}.img is up to date. Nothing to do."
fi
