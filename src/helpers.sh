#!/usr/bin/env bash
set -Eeuo pipefail

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "$1" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: $1" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: $1" "\E[0m\n"; }

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

# Docker environment variables
: "${CPU_COUNT:="1"}"     # Number of virtualized CPUs
: "${RAM_COUNT:="256"}"   # Amount of memory
: "${WAN_IF:=""}"         # Physical WAN interface name
: "${LAN_IF:=""}"         # Physical LAN interface name
: "${USB_1:=""}"          # USB 1 vendor and device ID
: "${USB_2:=""}"          # USB 2 vendor and device ID
: "${PCI_1:=""}"          # PCI 1 slot (first number in lspci)
: "${PCI_2:=""}"          # PCI 2 slot (first number in lspci)
: "${FORWARD_LUCI:=""}"   # Make LuCI OpenWrt web interface accessible via host LAN
: "${LUCI_WEB_BUTTON_JSON:=""}"   # Adapt the "OpenWrt LuCI web interface" button to your needs.
: "${OPENWRT_AFTER_BOOT_CMD:=""}" # User command or script to run after OpenWrt is booted
: "${DISABLE_OPENWRT_AUTO_UPGRADE:=""}"  # Disables the OpenWrt upgrade check every container startup
: "${IMAGE_SIZE_ON_INIT:=""}"  # New OpenWrt disk image size in MiB
: "${IS_U_OS_APP:=""}"    # By default this container is not a u-OS app
: "${DEBUG:=""}"          # Disable debugging
