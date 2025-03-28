#!/usr/bin/env bash
set -Eeuo pipefail

. /var/vm/openwrt_metadata.conf
. /run/helpers.sh

[ ! -f "/run/init_container.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

echo "❯ Starting OpenWrt $OPENWRT_VERSION for Docker ..."
echo "❯ For support visit https://github.com/AlbrechtL/openwrt-docker"
echo

# Show alpine version
echo "**** Alpine release ****"
cat /etc/*release*
echo "**** End Alpine release information ****"

echo "CPU architecture: '$(arch)'"

# Check system
if [ ! -d "/dev/shm" ]; then
  error "Directory /dev/shm not found!" && exit 14
else
  [ ! -d "/run/shm" ] && ln -s /dev/shm /run/shm
fi

# Check folder
STORAGE="/storage"
if [ ! -d "$STORAGE" ]; then
  error "Storage folder ($STORAGE) not found!" && exit 13
fi

# Generate page for meta information
echo "* Content of /var/vm/openwrt_metadata.conf *" > /var/www/system_info.txt
cat /var/vm/openwrt_metadata.conf >> /var/www/system_info.txt
echo $'\n' >> /var/www/system_info.txt

echo "* Environment variables *" >> /var/www/system_info.txt
export >> /var/www/system_info.txt
echo $'\n' >> /var/www/system_info.txt

echo "* USB devices *" >> /var/www/system_info.txt
set +e # Enable that the next command can fail
lsusb >> /var/www/system_info.txt
echo $'\n' >> /var/www/system_info.txt
set -e # Revert set +a

echo "* PCI devices *" >> /var/www/system_info.txt
set +e # Enable that the next command can fail
lspci >> /var/www/system_info.txt
set -e # Revert set +a

# ******* nginx handling *******
cp -f /var/www/nginx.conf /etc/nginx/http.d/web.conf
cp -r /var/www/* /run/shm

# ******* LuCi forwarding handling *******
LAN_IF_NAME=$(echo $LAN_IF | cut -d',' -f1)
LAN_IF_OPTION=$(echo $LAN_IF | cut -d',' -f2)
if [[ $FORWARD_LUCI = "true" && $LAN_IF_NAME = "veth" ]]; then
  info "Enable LuCI forwarding to host LAN at port 9000"
  LUCI_COMMAND="nsenter --target 1 --uts --net --ipc nginx -c /var/www/nginx-luci.conf"

  if [[ $LAN_IF_OPTION = "nofixedip" ]]; then
    warn "Please ensure that the virtual Ethernet interface is configured correctly. The LuCI reverse proxy is expecting OpenWrt at the IP address 172.31.1.1"
  fi
else
  if [[ $FORWARD_LUCI = "true" ]]; then
    warn "LuCI forwarding is only available if environment variable is set to LAN_IF: 'veth'. Currently LAN_IF=$LAN_IF."
  fi
  LUCI_COMMAND="sh -c 'sleep infinity'" # TODO: Find something better. Multirun needs something to run.
fi

# ******* OpenWrt run command after boot handling *******
if [[ -z "${OPENWRT_AFTER_BOOT_CMD}" ]]; then
  OPENWRT_MULTIRUN_CMD="sh -c 'sleep infinity'" # TODO: Find something better. Multirun needs something to run.
else
  info "Invoke command '${OPENWRT_AFTER_BOOT_CMD}' into OpenWrt after it is booted"
  OPENWRT_MULTIRUN_CMD="/run/run_command_after_openwrt_boot.sh '${OPENWRT_AFTER_BOOT_CMD}'"
fi


# Start processes
exec multirun \
  "/run/cleanup_container.sh" \
  "qemu-openwrt-web-backend" \
  "nginx" \
  "/run/run_openwrt.sh" \
  "$LUCI_COMMAND" \
  "$OPENWRT_MULTIRUN_CMD"
