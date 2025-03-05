#!/usr/bin/env bash
set -Eeuo pipefail

. /run/helpers.sh

cleanup() {
    info "Container is stopping. Performing cleanup..."
    # Add your cleanup commands here

    if [ -n "$PCI_1" ]; then
        if [[ "$PCI_1" == 0000:* ]]; then
            PCI_SLOT="$PCI_1"
        else
            PCI_SLOT="0000:$PCI_1"
        fi
        echo "Attaching PCI device $PCI_SLOT back to the host"
        echo 1 > /sys/bus/pci/devices/$PCI_SLOT/remove
        echo 1 > /sys/bus/pci/rescan
    fi


    echo "Cleanup complete."
    exit 0
}

# Catch signals and call cleanup function
trap cleanup SIGTERM SIGINT

# Wait forever to prevent that multirun will stop the complete container
# This script purpose is only to catch the signal SIGTERM and SIGINT and to execute some last commands

# Put OpenWrt bootlog into container log
if [[ $DEBUG = "true" ]]; then
 # Get bootlog via TCP, remove non-printable characters
 nc -l -p 4555 | sed 's/[^[:print:]]//g' |
 while IFS= read -r line; do
    echo $line
 done & wait
fi

sleep infinity & wait