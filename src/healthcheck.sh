#!/bin/sh

# Check if the output contains "OpenWrt"
if /run/qemu_qmp.sh -V | grep -q "OpenWrt"; then
    # If "OpenWrt" is found, exit with status 0 (healthy)
    exit 0
else
    # If "OpenWrt" is not found, exit with status 1 (unhealthy)
    exit 1
fi
