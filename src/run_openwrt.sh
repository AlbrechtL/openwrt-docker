#!/usr/bin/env bash

# Based on https://github.com/qemus/qemu-docker
set -Eeuo pipefail
trap - ERR

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh
. /run/install_openwrt_rootfs.sh
. /run/migrate_openwrt_rootfs.sh

# CPU architecture specific
CPU_ARCH=$(arch)

VERS=$(qemu-system-"$CPU_ARCH" --version | head -n 1 | cut -d '(' -f 1)
FILE=/storage/squashfs-combined-${OPENWRT_IMAGE_ID}.img

# Attach physical interfaces to Docker container
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

  # Check if interface exists
  if ! nsenter --target 1 --uts --net --ipc --mount ip link show "$HOST_IF" &> /dev/null; then
    info "Host Ethernet interface $HOST_IF does not exists. It can be a wrong interface name or the Ethernet interface is already assigend to this container."
    return
  fi

  PID_CONTAINTER=$(nsenter --target 1 --uts --net --ipc --mount docker inspect -f '{{.State.Pid}}' $(cat /etc/hostname))
  nsenter --target 1 --uts --net --ipc --mount mkdir -p /var/run/netns
  nsenter --target 1 --uts --net --ipc --mount ln -s /proc/$PID_CONTAINTER/ns/net /var/run/netns/$PID_CONTAINTER
  nsenter --target 1 --uts --net --ipc --mount ip link set $HOST_IF netns $PID_CONTAINTER name $CONTAINER_IF
  nsenter --target 1 --uts --net --ipc --mount ip netns exec $PID_CONTAINTER ip link set $CONTAINER_IF up
  nsenter --target 1 --uts --net --ipc --mount rm /var/run/netns/$PID_CONTAINTER

  #ip link add link $CONTAINER_IF name $QEMU_IF type ipvlan mode l2
  #ip link add link $CONTAINER_IF name $QEMU_IF type macvtap mode bridge
  ip link add link $CONTAINER_IF name $QEMU_IF type macvtap mode passthru

  # Enable multicast (important for IPv6)
  #ip link set dev $QEMU_IF allmulticast on # not working for some reason
  ip link set dev $QEMU_IF promisc on # lets use the hammer

  # Create MAC address for new interface
  QEMU_MAC_OUI="52:54:00"
  read MAC </sys/class/net/$CONTAINER_IF/address
  QEMU_IF_MAC=${QEMU_MAC_OUI}${MAC:8} # Replaces the 8 first characters of the original MAC

  # Active new interface
  ip link set $QEMU_IF address $QEMU_IF_MAC up
  #ip link set $QEMU_IF up
}

# Create veth pairs between host system and Docker container
attach_veth_if () {
  VETH_IF_HOST=$1
  VETH_IF_CONTAINER=$2
  QEMU_IF=$3
  OPTION=$4

  info "Creating virtual Ethernet interfaces pairs between host system ($VETH_IF_HOST) and container ($VETH_IF_CONTAINER)..."

  if ! nsenter --target 1 --uts --net --ipc --mount ip link show "$VETH_IF_HOST" &> /dev/null; then
    # Create veth pair
    nsenter --target 1 --uts --net --ipc --mount ip link add $VETH_IF_HOST type veth peer name $VETH_IF_CONTAINER
    nsenter --target 1 --uts --net --ipc --mount ip link set $VETH_IF_HOST up

    if [[ -z "${IS_U_OS_APP}" && $OPTION != "nofixedip" ]]; then
      nsenter --target 1 --uts --net --ipc --mount ip addr add 172.31.1.2/24 dev $VETH_IF_HOST
    fi
  else
    info "Virtual Ethernet interface $VETH_IF_HOST already exists. Assuming pairs is already created."
  fi

  if nsenter --target 1 --uts --net --ipc --mount ip link show "$VETH_IF_CONTAINER" &> /dev/null; then
    # Put second pair into container
    PID_CONTAINTER=$(nsenter --target 1 --uts --net --ipc --mount docker inspect -f '{{.State.Pid}}' $(cat /etc/hostname))
    nsenter --target 1 --uts --net --ipc --mount mkdir -p /var/run/netns
    nsenter --target 1 --uts --net --ipc --mount ln -s /proc/$PID_CONTAINTER/ns/net /var/run/netns/$PID_CONTAINTER
    nsenter --target 1 --uts --net --ipc --mount ip link set $VETH_IF_CONTAINER netns $PID_CONTAINTER
    nsenter --target 1 --uts --net --ipc --mount ip netns exec $PID_CONTAINTER ip link set $VETH_IF_CONTAINER up
    nsenter --target 1 --uts --net --ipc --mount rm /var/run/netns/$PID_CONTAINTER

    ip link add link $VETH_IF_CONTAINER name $QEMU_IF type macvtap mode passthru
    ip link set $QEMU_IF up
  fi

  # Only as u-OS app
  if [[ -n "${IS_U_OS_APP}" ]]; then
    # Check if u-OS webserver is already configured
    if  ! nsenter --target 1 --uts --net --ipc --mount grep -q "app-openwrt0" "/usr/lib/uc-http-server/ucu.yml" ; then
      info "Adding app-openwrt0 to /usr/lib/uc-http-server/ucu.yml ..."
      nsenter --target 1 --uts --net --ipc --mount mount -o remount,rw /
      nsenter --target 1 --uts --net --ipc --mount sed -i "s/, 'usb-x1'/, 'usb-x1', 'app-openwrt0'/g" /usr/lib/uc-http-server/ucu.yml
      nsenter --target 1 --uts --net --ipc --mount mount -o remount,ro /
    fi

    if ! nsenter --target 1 --uts --net --ipc --mount sh -c "test -f /var/lib/systemd/network/app-openwrt0.network"; then
      info "Creating /var/lib/systemd/network/app-openwrt0.network ..."
      nsenter --target 1 --uts --net --ipc --mount sh -c "echo '[Match]' > /var/lib/systemd/network/app-openwrt0.network"
      nsenter --target 1 --uts --net --ipc --mount sh -c "echo 'Name=app-openwrt0' >> /var/lib/systemd/network/app-openwrt0.network"
      nsenter --target 1 --uts --net --ipc --mount sh -c "echo '[Network]' >> /var/lib/systemd/network/app-openwrt0.network"
      nsenter --target 1 --uts --net --ipc --mount sh -c "echo 'DHCP=yes' >> /var/lib/systemd/network/app-openwrt0.network"
      nsenter --target 1 --uts --net --ipc --mount mount -o remount,rw /
      nsenter --target 1 --uts --net --ipc --mount cp /var/lib/systemd/network/app-openwrt0.network /usr/lib/systemd/network/app-openwrt0.network
      nsenter --target 1 --uts --net --ipc --mount mount -o remount,ro /
    fi

    if nsenter --target 1 --uts --net --ipc --mount ip link show app-openwrt0  &> /dev/null; then
      info "Deleting previous app-openwrt0 Ethernet device ..."
      nsenter --target 1 --uts --net --ipc --mount ip link del app-openwrt0
    fi

    info "Adding a bridge app-openwrt0 as workaround because uc-http-server cannot handle veths peer_ifindex "@ifXX" e.g. veth-openwrt0@if32"
    nsenter --target 1 --uts --net --ipc --mount ip link add name app-openwrt0 type bridge
    nsenter --target 1 --uts --net --ipc --mount ip link set dev app-openwrt0 up
    nsenter --target 1 --uts --net --ipc --mount ip link set veth-openwrt0 master app-openwrt0
    nsenter --target 1 --uts --net --ipc --mount systemctl restart uc-http-server
  fi
}

# Handle dirfferent architectures
if [ $CPU_ARCH = "aarch64" ]; then
  CPU_ARGS="-M virt -bios /usr/share/qemu/edk2-aarch64-code.fd -vga none -device ramfb"
else
  CPU_ARGS="-M pc -vga std"
fi

# Check KVM
info "Checking for KVM ..."
KVM_ERR=""
if [ ! -e /dev/kvm ]; then
    KVM_ERR="(device file missing)"
  else
    if ! sh -c 'echo -n > /dev/kvm' &> /dev/null; then
      KVM_ERR="(no write access)"
    else
      info "KVM detected"
    fi
fi
if [ -n "$KVM_ERR" ]; then
    error "KVM acceleration not detected $KVM_ERR."
fi

# Attach physical PHY to container
LAN_ARGS=""
LAN_IF_NAME=$(echo $LAN_IF | cut -d',' -f1)
LAN_IF_OPTION=$(echo $LAN_IF | cut -d',' -f2)
if [[ -z "${LAN_IF_NAME}" || $LAN_IF_NAME = "host" ]]; then
  LAN_ARGS="-device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24"
elif [[ $LAN_IF_NAME = "veth" ]]; then
  attach_veth_if veth-openwrt0 veth1 qlan1 $LAN_IF_OPTION
  exec 30<>/dev/tap$(cat /sys/class/net/qlan1/ifindex)
  LAN_ARGS="-device virtio-net-pci,netdev=hostnet0,mac=$(cat /sys/class/net/qlan1/address) \
    -netdev tap,fd=30,id=hostnet0"
else
  HOST_LAN_IF=$LAN_IF_NAME
  attach_eth_if $HOST_LAN_IF $HOST_LAN_IF qlan0
  exec 30<>/dev/tap$(cat /sys/class/net/qlan0/ifindex)
  LAN_ARGS="-device virtio-net-pci,netdev=hostnet0,mac=$(cat /sys/class/net/qlan0/address) \
    -netdev tap,fd=30,id=hostnet0"
fi

WAN_ARGS=""
if [[ -z "${WAN_IF}" || $WAN_IF = "host" ]]; then
  WAN_ARGS="-device virtio-net,netdev=qwan0 -netdev user,id=qwan0,hostfwd=tcp::8000-:80,hostfwd=tcp::8022-:22"
elif [[ $WAN_IF = "none" ]]; then
  WAN_ARGS=""
else
  HOST_WAN_IF=$WAN_IF
  attach_eth_if $HOST_WAN_IF $HOST_WAN_IF qwan0
  exec 31<>/dev/tap$(cat /sys/class/net/qwan0/ifindex)
  WAN_ARGS="-device virtio-net-pci,netdev=hostnet1,mac=$(cat /sys/class/net/qwan0/address) \
    -netdev tap,fd=31,id=hostnet1"
fi

# Attach USB interface
USB_ARGS=""
USB_1_ARGS=""
USB_2_ARGS=""
if [[ -z "${USB_1}" ]]; then
  USB_1_ARGS=""
else
  USB_VID_1=$(echo $USB_1 | cut -d':' -f1)
  USB_PID_1=$(echo $USB_1 | cut -d':' -f2)
  USB_1_ARGS="-device usb-host,vendorid=0x$USB_VID_1,productid=0x$USB_PID_1"
fi

if [[ -z "${USB_2}" ]]; then
  USB_2_ARGS=""
else
  USB_VID_2=$(echo $USB_2 | cut -d':' -f1)
  USB_PID_2=$(echo $USB_2 | cut -d':' -f2)
  USB_2_ARGS="-device usb-host,vendorid=0x$USB_VID_2,productid=0x$USB_PID_2"
fi

USB_ARGS="${USB_1_ARGS} ${USB_2_ARGS}"

info "Booting image using $VERS..."

# See qemu command if debug is enabled
[[ "$DEBUG" == [Yy1]* ]] && set -x

#************************ FINAL BOOTING ************************
exec qemu-system-"$CPU_ARCH" \
--enable-kvm -cpu host \
-m $RAM_COUNT \
-nodefaults \
 $CPU_ARGS -smp $CPU_COUNT \
-display vnc=:0,websocket=5700 \
-blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=${FILE} \
-device virtio-blk-pci,drive=hd0 \
-device qemu-xhci -device usb-kbd \
 $LAN_ARGS \
 $WAN_ARGS \
 $USB_ARGS \
 -qmp unix:/run/qmp-sock,server=on,wait=off \
 -chardev socket,path=/run/qga.sock,server=on,wait=off,id=qga0 \
 -device virtio-serial \
 -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0

# -kernel /var/vm/kernel.bin -append "root=fe00 console=tty0" \
