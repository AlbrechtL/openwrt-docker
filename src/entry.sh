#!/usr/bin/env bash

# Based on https://github.com/qemus/qemu-docker
set -Eeuo pipefail


APP="OpenWrt"
SUPPORT="https://github.com/AlbrechtL/openwrt-docker-arm64-build"

attach_eth_if () {
  HOST_IF=$1
  CONTAINER_IF=$2
  QEMU_IF=$3
  # Privilige=true and pid=host mode necessary
  # Sources
  # * https://serverfault.com/questions/688483/assign-physical-interface-to-docker-exclusively
  # * https://medium.com/lucjuggery/a-container-to-access-the-shell-of-the-host-2c7c227c64e9
  # * https://developers.redhat.com/blog/2018/10/22/introduction-to-linux-interfaces-for-virtual-networking#
      
  info "Attaching physical Ethernet interface $HOST_IF into container with the name $CONTAINER_IF ..."
  PID_CONTAINTER=$(nsenter --target 1 --uts --net --ipc --mount docker inspect -f '{{.State.Pid}}' $(cat /etc/hostname))
  nsenter --target 1 --uts --net --ipc --mount mkdir -p /var/run/netns
  nsenter --target 1 --uts --net --ipc --mount ln -s /proc/$PID_CONTAINTER/ns/net /var/run/netns/$PID_CONTAINTER
  nsenter --target 1 --uts --net --ipc --mount ip link set $HOST_IF netns $PID_CONTAINTER name $CONTAINER_IF
  nsenter --target 1 --uts --net --ipc --mount ip netns exec $PID_CONTAINTER ip link set $CONTAINER_IF up
  nsenter --target 1 --uts --net --ipc --mount rm /var/run/netns/$PID_CONTAINTER

  #ip link add link $CONTAINER_IF name $QEMU_IF type ipvlan mode l2
  #ip link add link $CONTAINER_IF name $QEMU_IF type macvtap mode bridge
  ip link add link $CONTAINER_IF name $QEMU_IF type macvtap mode passthru
  ip link set $QEMU_IF up
}

cd /run

# Initialize system
. reset.sh      

trap - ERR

# Check if rootfs is in volume
FILE=/storage/rootfs.img
if [ -f "$FILE" ]; then
    info "$FILE exists. Nothing to do."
else 
    info "$FILE does not exist. Copying image to storage ..."
    cp /var/vm/rootfs.img.gz /storage/rootfs.img.gz
    gzip -d /storage/rootfs.img.gz
    
    info "Copy some additional files into the image"
    mount /storage/rootfs.img /mnt
    cp /var/vm/* /mnt/root
    umount /mnt
fi


info "Activating web VNC ..."
[ ! -f "$INFO" ] && error "File $INFO not found?!"
rm -f "$INFO"
[ ! -f "$PAGE" ] && error "File $PAGE not found?!"
rm -f "$PAGE"


info "Checking for KVM ..."
KVM_ERR=""
CPU_ARGS="-cpu cortex-a53"
if [ ! -e /dev/kvm ]; then
    KVM_ERR="(device file missing)"
  else
    if ! sh -c 'echo -n > /dev/kvm' &> /dev/null; then
      KVM_ERR="(no write access)"
    else
      CPU_ARGS="--enable-kvm -cpu host"
      info "KVM detected"
    fi
fi
if [ -n "$KVM_ERR" ]; then
    info "KVM acceleration not detected $KVM_ERR, this will cause a major loss of performance."
fi

# Attach physical PHY to container
LAN_ARGS=""
if [[ -z "${LAN_IF}" ]]; then
  LAN_ARGS="-device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24"
else
  HOST_LAN_IF=$LAN_IF
  attach_eth_if $HOST_LAN_IF $HOST_LAN_IF qlan0
  exec 30<>/dev/tap$(cat /sys/class/net/qlan0/ifindex)
  LAN_ARGS="-device virtio-net-pci,netdev=hostnet0 -netdev tap,fd=30,id=hostnet0"
fi

WAN_ARGS=""
if [[ -z "${WAN_IF}" ]]; then
  WAN_ARGS="-device virtio-net,netdev=qwan0 -netdev user,id=qwan0,hostfwd=tcp::8000-:80"
else
  HOST_WAN_IF=$WAN_IF
  attach_eth_if $HOST_WAN_IF $HOST_WAN_IF qwan0
  exec 31<>/dev/tap$(cat /sys/class/net/qwan0/ifindex)
  WAN_ARGS="-device virtio-net-pci,netdev=hostnet1 -netdev tap,fd=31,id=hostnet1"
fi

# Attach USB interface
USB_ARGS=""
if [[ -z "${USB_VID_1}" || -z "${USB_PID_1}" ]]; then
  USB_ARGS=""
else
  USB_ARGS="-device usb-host,vendorid=0x$USB_VID_1,productid=0x$USB_PID_1"
fi

info "Booting image using $VERS..."

[[ "$DEBUG" == [Yy1]* ]] && set -x
exec qemu-system-aarch64 -M virt \
-m 128 \
-nodefaults \
 $CPU_ARGS -smp $CPU_COUNT \
-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
-display vnc=:0,websocket=5700 \
-vga none -device ramfb \
-kernel /var/vm/kernel.bin -append "root=fe00 console=tty0" \
-blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/storage/rootfs.img \
-device virtio-blk-pci,drive=hd0 \
-device qemu-xhci -device usb-kbd \
 $LAN_ARGS \
 $WAN_ARGS \
 $USB_ARGS
 
# -device virtio-net,netdev=qlan1 -netdev user,id=qlan1,net=192.168.1.0/24,hostfwd=tcp::8000-192.168.1.1:80 \
# -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/openwrt-armsr-armv8-generic-ext4-combined.img \
