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

  # Create MAC address for new interface
  QEMU_MAC_OUI="52:54:00"
  read MAC </sys/class/net/$CONTAINER_IF/address
  QEMU_IF_MAC=${QEMU_MAC_OUI}${MAC:8} # Replaces the 8 first characters of the original MAC

  # Active new interface
  ip link set $QEMU_IF address $QEMU_IF_MAC up
  #ip link set $QEMU_IF up
}

cd /run

# Initialize system
. reset.sh      

trap - ERR

# Check if rootfs is in volume
FILE=/storage/rootfs-${OPENWRT_VERSION}.img
if [ -f "$FILE" ]; then
    info "$FILE exists. Nothing to do."
else 
    info "$FILE does not exist. Copying rootfs-${OPENWRT_VERSION}.img to storage ..."
    cp /var/vm/rootfs-${OPENWRT_VERSION}.img.gz /storage/rootfs-${OPENWRT_VERSION}.img.gz
    gzip -d /storage/rootfs-${OPENWRT_VERSION}.img.gz
    
    info "Inject some additional files into the image"
    mount /storage/rootfs-${OPENWRT_VERSION}.img /mnt
    # mount -o offset=$((512*262656)) /storage/disk.img /mnt # combined image ext4 partition starts at offset 262656
    chmod +x /var/vm/openwrt_additional/bin/*
    cp /var/vm/openwrt_additional/bin/* /mnt/usr/bin/
    umount /mnt

    if [ -f "/storage/current_version" ]; then
      mv /storage/current_version /storage/old_version
    fi

    touch /storage/current_version
    echo "rootfs-${OPENWRT_VERSION}.img" > /storage/current_version
fi

# Enable VNC
info "Activating web VNC ..."
[ ! -f "$INFO" ] && error "File $INFO not found?!"
rm -f "$INFO"
[ ! -f "$PAGE" ] && error "File $PAGE not found?!"
rm -f "$PAGE"


# Check KVM
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
  LAN_ARGS="-device virtio-net-pci,netdev=hostnet0,mac=$(cat /sys/class/net/qlan0/address) \
    -netdev tap,fd=30,id=hostnet0"
fi

WAN_ARGS=""
if [[ -z "${WAN_IF}" ]]; then
  WAN_ARGS="-device virtio-net,netdev=qwan0 -netdev user,id=qwan0,hostfwd=tcp::8000-:80,hostfwd=tcp::8022-:22"
else
  HOST_WAN_IF=$WAN_IF
  attach_eth_if $HOST_WAN_IF $HOST_WAN_IF qwan0
  exec 31<>/dev/tap$(cat /sys/class/net/qwan0/ifindex)
  WAN_ARGS="-device virtio-net-pci,netdev=hostnet1,mac=$(cat /sys/class/net/qwan0/address) \
    -netdev tap,fd=31,id=hostnet1"
fi

# Attach USB interface
USB_ARGS=""
if [[ -z "${USB_VID_1}" || -z "${USB_PID_1}" ]]; then
  USB_ARGS=""
else
  USB_ARGS="-device usb-host,vendorid=0x$USB_VID_1,productid=0x$USB_PID_1"
fi

# Migrate settings from old OpenWrt version to new one
if [ -f /storage/old_version ]; then
  OLD_VERSION_ROOTFS=`cat /storage/old_version`

  info "Migrate settings from $OLD_VERSION_ROOTFS to rootfs-${OPENWRT_VERSION}.img. This can take some time because we need to boot openwrt multiple times."
  
  mount /storage/$OLD_VERSION_ROOTFS /mnt
  mv /mnt/etc/rc.local /mnt/etc/rc.local.disabled
  cp /var/vm/openwrt_additional/do_backup_rc.local /mnt/etc/rc.local
  chmod +x /mnt/etc/rc.local
  umount /mnt

  info "Boot previos $OLD_VERSION_ROOTFS to get config"
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
fi



# See qemu command if debug is enabled
[[ "$DEBUG" == [Yy1]* ]] && set -x

#************************ FINAL BOOTING ************************

info "Booting image using $VERS..."
exec qemu-system-aarch64 -M virt \
-m 128 \
-nodefaults \
 $CPU_ARGS -smp $CPU_COUNT \
-bios /usr/share/qemu/edk2-aarch64-code.fd \
-display vnc=:0,websocket=5700 \
-vga none -device ramfb \
-kernel /var/vm/kernel.bin -append "root=fe00 console=tty0" \
-blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=${FILE} \
-device virtio-blk-pci,drive=hd0 \
-device qemu-xhci -device usb-kbd \
 $LAN_ARGS \
 $WAN_ARGS \
 $USB_ARGS
 
# -device virtio-net,netdev=qlan1 -netdev user,id=qlan1,net=192.168.1.0/24,hostfwd=tcp::8000-192.168.1.1:80 \
# -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/openwrt-armsr-armv8-generic-ext4-combined.img \
