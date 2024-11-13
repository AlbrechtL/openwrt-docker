#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

SQUASHFS_COMBINED=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img
CPU_ARCH=$(arch)

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
      /run/mount_openwrt_squashfs_combined.sh /storage/$OLD_SQUASHFS_COMBINED $CPU_ARCH
      chroot /mnt/ mkdir -p /var/lock
      chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
      mv /mnt/tmp/openwrt_config.tar.gz /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz
      /run/mount_openwrt_squashfs_combined.sh -u
  fi

  # Put config backup to new squashfs-combined
  /run/mount_openwrt_squashfs_combined.sh $SQUASHFS_COMBINED $CPU_ARCH
  mkdir -p /mnt/root/backup
  cp /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz /mnt/root/backup/config.tar.gz
  chroot /mnt/ mkdir -p /var/lock
  chroot /mnt /sbin/sysupgrade -r /root/backup/config.tar.gz
  /run/mount_openwrt_squashfs_combined.sh -u 

  # Finally remove old squashfs-combined and old files
  rm /storage/$OLD_SQUASHFS_COMBINED
  rm /storage/old_version
  rm /storage/config-`basename $OLD_SQUASHFS_COMBINED.img`.tar.gz
else
  info "squashfs-combined-${OPENWRT_IMAGE_ID}.img is up to date. Nothing to do."
fi