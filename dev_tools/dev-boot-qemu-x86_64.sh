#!/bin/bash
#
# boots an OpenWrt aarch64 image with qemu for development purposes
#
# Copyright Albrecht Lohofener 2024 <albrechtloh@gmx.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.


# Assign arguments to variables
IMAGE_FILE="$1"
SSH_PORT=8022

qemu-system-x86_64 -M pc -nographic -nodefaults -m 256 --enable-kvm \
-blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=$IMAGE_FILE \
-device virtio-blk-pci,drive=hd0 \
-device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24,hostfwd=tcp::$SSH_PORT-192.168.1.1:22 \
-device virtio-net,netdev=qwan0 -netdev user,id=qwan0 \
-qmp unix:/run/qmp-sock,server=on,wait=off \
-chardev socket,path=/run/qga.sock,server=on,wait=off,id=qga0 \
-device virtio-serial \
-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
-serial stdio