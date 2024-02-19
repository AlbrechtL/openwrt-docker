#!/usr/bin/env bash

set -Eeuo pipefail
trap - ERR

. /run/helpers.sh

CURRENT_VERSION_ROOTFS=`cat /storage/current_version`

# Stop openwrt
echo "****** Stop openwrt ******"
supervisorctl stop openwrt

# Do factory reset
echo "****** Do factory reset ******"

echo "Deleting all files in /storage ..."
ls /storage/
rm -f /storage/*

# Start openwrt again
echo "****** Start openwrt again ******"
supervisorctl start openwrt