#!/usr/bin/env bash
set -Eeuo pipefail

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "$1" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: $1" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: $1" "\E[0m\n" >&2; }

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

[ ! -f "/run/entry.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

echo "❯ Starting $APP for Docker v$(</run/version)..."
echo "❯ For support visit $SUPPORT"
echo

# Docker environment variables

: "${CPU_COUNT:=""}"      # Physical LAN interface name
: "${WAN_IF:=""}"         # Physical WAN interface name
: "${LAN_IF:=""}"         # Physical LAN interface name
: "${USB_VID_1:=""}"      # USB vendor ID
: "${USB_PID_1:=""}"      # USB product ID
: "${IS_U_OS_APP:=""}"    # By default this container is not a u-OS app 
: "${DEBUG:="N"}"         # Disable debugging

# Helper variables

STORAGE="/storage"
INFO="/run/shm/msg.html"
PAGE="/run/shm/index.html"
TEMPLATE="/var/www/index.html"
FOOTER1="$APP for Docker v$(</run/version)"
FOOTER2="<a href='$SUPPORT'>$SUPPORT</a>"

KERNEL=$(uname -r | cut -b 1)
MINOR=$(uname -r | cut -d '.' -f2)
ARCH=$(uname -m)
VERS=$(qemu-system-aarch64 --version | head -n 1 | cut -d '(' -f 1)

# Check system
if [ ! -d "/dev/shm" ]; then
  error "Directory /dev/shm not found!" && exit 14
else
  [ ! -d "/run/shm" ] && ln -s /dev/shm /run/shm
fi

# Check folder
if [ ! -d "$STORAGE" ]; then
  error "Storage folder ($STORAGE) not found!" && exit 13
fi

# Check u-OS app
if [[ -z "${IS_U_OS_APP}" ]]; then
  info "Detected generic container"
  cp -f /var/www/nginx.conf.generic /etc/nginx/http.d/web.conf
else
  info "Detected u-OS app"
  cp -f  /var/www/nginx.conf.u-os-app /etc/nginx/http.d/web.conf
fi

# Start webserver
cp -r /var/www/* /run/shm
supervisorctl start nginx

# ******* script-server handeling *******
# Ugly hack to enable iframe usage
sed -i "s/'X-Frame-Options', 'DENY'/ \
'X-Frame-Options', 'ALLOWALL'/g" \
/usr/share/script-server/src/web/server.py 

# Usage of default logging.json'
cp -f /usr/share/script-server/conf/logging.json /var/script-server/logging.json

# Start script-server
/var/lib/script-server-env/bin/python \
/usr/share/script-server/launcher.py -d /var/script-server > /var/log/script-server.log &

return 0
