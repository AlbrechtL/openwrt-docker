#!/usr/bin/env bash
set -Eeuo pipefail

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "$1" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: $1" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: $1" "\E[0m\n" >&2; }

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

# Docker environment variables
: "${CPU_COUNT:=""}"      # Physical LAN interface name
: "${WAN_IF:=""}"         # Physical WAN interface name
: "${LAN_IF:=""}"         # Physical LAN interface name
: "${USB_VID_1:=""}"      # USB vendor ID
: "${USB_PID_1:=""}"      # USB product ID
: "${FORWARD_LUCI:=""}"   # Make LuCI OpenWrt web interface accessible via host LAN
: "${IS_U_OS_APP:=""}"    # By default this container is not a u-OS app 
: "${DEBUG:="N"}"         # Disable debugging
