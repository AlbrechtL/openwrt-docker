#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

if [ ! "$1" = "--file_upload" ] ; then
    echo "Error: expected argument --file_upload"
    exit 1
fi

CURRENT_VERSION_ROOTFS=`cat /storage/current_version`

# Stop openwrt
echo "****** shutdown openwrt ******"
/run/qemu_qmp.sh -S

until ! supervisorctl status openwrt | grep RUNNING
do
    sleep 1
done

# Get config
echo "****** Mount $CURRENT_VERSION_ROOTFS ******"
mount /storage/$CURRENT_VERSION_ROOTFS /mnt

echo "****** Restore $2 ******"
cp $2 /mnt/tmp/openwrt_config.tar.gz
chroot /mnt/ mkdir -p /var/lock
chroot /mnt /sbin/sysupgrade -r /tmp/openwrt_config.tar.gz

echo "****** umount $CURRENT_VERSION_ROOTFS ******"
umount /mnt

# Start openwrt again
echo "****** Start openwrt again ******"
supervisorctl start openwrt
