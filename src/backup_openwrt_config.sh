#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

CURRENT_VERSION_ROOTFS=`cat /storage/current_version`

# Stop openwrt
echo "****** Stop openwrt ******"
supervisorctl stop openwrt

# Get config
echo "****** Mount $CURRENT_VERSION_ROOTFS ******"
mount /storage/$CURRENT_VERSION_ROOTFS /mnt

echo "****** Create openwrt_config.tar.gz ******"
chroot /mnt /sbin/sysupgrade -k -b /tmp/openwrt_config.tar.gz
mv /mnt/tmp/openwrt_config.tar.gz /tmp/openwrt_config.tar.gz

echo "****** umount $CURRENT_VERSION_ROOTFS ******"
umount /mnt

# Start openwrt again
echo "****** Start openwrt again ******"
supervisorctl start openwrt
