#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

# Migrate settings from old OpenWrt version to new one
if [ -f /storage/old_version ]; then
  OLD_VERSION_ROOTFS=`cat /storage/old_version`

  info "Migrate settings from $OLD_VERSION_ROOTFS to rootfs-${OPENWRT_VERSION}.img. This can take some time because we need to boot openwrt multiple times."
  
  mount /storage/$OLD_VERSION_ROOTFS /mnt
  mv /mnt/etc/rc.local /mnt/etc/rc.local.disabled
  cp /var/vm/openwrt_additional/do_backup_rc.local /mnt/etc/rc.local
  chmod +x /mnt/etc/rc.local
  umount /mnt

  info "Boot previous $OLD_VERSION_ROOTFS to get config"
  qemu-system-aarch64 -M virt \
  -m 128 \
  -nodefaults \
  $CPU_ARGS -smp $CPU_COUNT \
  -bios /usr/share/qemu/edk2-aarch64-code.fd \
  -display vnc=:0,websocket=5700 \
  -vga none -device ramfb \
  -kernel /var/vm/kernel.bin -append "root=fe00 console=tty0" \
  -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/storage/${OLD_VERSION_ROOTFS} \
  -device virtio-blk-pci,drive=hd0 \
  -device qemu-xhci -device usb-kbd

  # Get config backup from old rootfs
  mount /storage/$OLD_VERSION_ROOTFS /mnt
  rm /mnt/etc/rc.local
  mv /mnt/etc/rc.local.disabled /mnt/etc/rc.local
  
  if [ -f /mnt/root/backup/config.tar.gz ]; then
    cp /mnt/root/backup/config.tar.gz /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz
  else
    error "No config.tar.gz in $OLD_VERSION_ROOTFS found"
  fi
  umount /mnt

  # Put config backup to new rootfs
  mount $FILE /mnt
  mkdir -p /mnt/root/backup
  cp /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz /mnt/root/backup/config.tar.gz
  
  mv /mnt/etc/rc.local /mnt/etc/rc.local.disabled
  cp /var/vm/openwrt_additional/restore_backup_rc.local /mnt/etc/rc.local
  chmod +x /mnt/etc/rc.local
  umount /mnt

  info "Boot current rootfs-${OPENWRT_VERSION}.img to install config"
  qemu-system-aarch64 -M virt \
  -m 128 \
  -nodefaults \
  $CPU_ARGS -smp $CPU_COUNT \
  -bios /usr/share/qemu/edk2-aarch64-code.fd \
  -display vnc=:0,websocket=5700 \
  -vga none -device ramfb \
  -kernel /var/vm/kernel.bin -append "root=fe00 console=tty0" \
  -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=${FILE}  \
  -device virtio-blk-pci,drive=hd0 \
  -device qemu-xhci -device usb-kbd

  mount $FILE /mnt
  rm /mnt/etc/rc.local
  mv /mnt/etc/rc.local.disabled /mnt/etc/rc.local
  mv /mnt/root/backup/config.tar.gz /mnt/root/backup/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz
  umount /mnt

  # Finally remove old rootfs and old files
  rm /storage/$OLD_VERSION_ROOTFS
  rm /storage/old_version
  rm /storage/config-`basename $OLD_VERSION_ROOTFS .img`.tar.gz
else
  info "rootfs-${OPENWRT_VERSION}.img is up to date. Nothing to do."
fi
