#!/bin/bash
#
# Copyright Albrecht Lohofener 2025 <albrechtloh@gmx.de>
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

# Display help page
show_help() {
    echo "Usage: $0 <argument-for-openwrt>"
    echo ""
    echo "This script checks if OpenWrt is booted."
    echo "Once successful, it executes the user command."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message and exit."
    exit 0
}

# Check for help flag
if [[ $1 == "-h" || $1 == "--help" ]]; then
    show_help
fi

# Polling the initial command until it succeeds
set +e # Enable that the next command can fail
while true; do
    # Check if OpenWrt is booted
    /run/qemu_qmp.sh -c 'logread | grep "procd: - init complete"' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Detected OpenWrt is booted"
        break
    fi

    # Wait for a short time before polling again
    sleep 2
    #echo "Waiting for OpenWrt boot..."
done
set -e # Revert set +e

# Execute the second command with the argument provided as input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <argument-for-qemu_qmp>"
    exit 1
fi

# Run user command
echo "Run command \"$1\""
/run/qemu_qmp.sh -c "$1"

# Never exit because multirun will exit the container then
sleep infinity