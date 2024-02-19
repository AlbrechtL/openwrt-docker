#!/usr/bin/env bash
set -Eeuo pipefail

. /run/helpers.sh

[ ! -f "/run/init_container.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

APP="OpenWrt"
SUPPORT="https://github.com/AlbrechtL/openwrt-docker-arm64-build"

echo "❯ Starting $APP for Docker v$(</run/version)..."
echo "❯ For support visit $SUPPORT"
echo


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

# Check u-OS app
if [[ -z "${IS_U_OS_APP}" ]]; then
  info "Detected generic container"
  cp -f /var/www/nginx.conf.generic /etc/nginx/http.d/web.conf
else
  info "Detected u-OS app"
  cp -f  /var/www/nginx.conf.u-os-app /etc/nginx/http.d/web.conf
fi


# ******* script-server handling *******
# Ugly hack to enable iframe usage
sed -i "s/'X-Frame-Options', 'DENY'/ \
'X-Frame-Options', 'ALLOWALL'/g" \
/usr/share/script-server/src/web/server.py 

# Usage of default logging.json'
cp -f /usr/share/script-server/conf/logging.json /var/script-server/logging.json

# Start script-server
supervisorctl start script-server


# ******* nginx handling *******
cp -r /var/www/* /run/shm
supervisorctl start nginx # Start webserver


# ******* OpenWrt handling *******
supervisorctl start openwrt # Start webserver