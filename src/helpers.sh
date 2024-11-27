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
: "${FORWARD_LUCI:=""}"   # Make LuCI OpenWrt web interface accessible via host LAN
: "${IS_U_OS_APP:=""}"    # By default this container is not a u-OS app 
: "${DEBUG:="N"}"         # Disable debugging
