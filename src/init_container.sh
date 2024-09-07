#!/usr/bin/env bash
set -Eeuo pipefail

. /run/helpers.sh

[ ! -f "/run/init_container.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

APP="OpenWrt"
SUPPORT="https://github.com/AlbrechtL/openwrt-docker"

echo "❯ Starting $APP for Docker v$(</run/version)..."
echo "❯ For support visit $SUPPORT"
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

# Check u-OS app
if [[ -z "${IS_U_OS_APP}" ]]; then
  info "Detected generic container"
  cp -f /var/www/nginx.conf.generic /etc/nginx/http.d/web.conf

  # Activate script-server
  sed -i 's/---SED_REPLACEMENT_TAG---/"script-server\/"/g' /var/www/index.html 
else
  info "Detected u-OS app"
  cp -f  /var/www/nginx.conf.u-os-app /etc/nginx/http.d/web.conf

  # Generate page for meta information
  echo "* Content of /var/vm/openwrt_metadata.conf *" > /var/www/system_info.txt
  cat /var/vm/openwrt_metadata.conf >> /var/www/system_info.txt
  echo $'\n' >> /var/www/system_info.txt

  echo "* Enviroment variables *" >> /var/www/system_info.txt
  export >> /var/www/system_info.txt
  echo $'\n' >> /var/www/system_info.txt

  echo "* USB devices *" >> /var/www/system_info.txt
  lsusb >> /var/www/system_info.txt

  sed -i 's/---SED_REPLACEMENT_TAG---/"system_info.txt"/g' /var/www/index.html 
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
supervisorctl start openwrt # Start openwrt

# ******* LuCi forwarding handling *******
if [[ $FORWARD_LUCI = "true" ]]; then
  if [[ $LAN_IF = "veth" ]]; then
    info "Enable LuCI forwading to host LAN at port 9000"
    supervisorctl start caddy # Start reverse proxy
  else
    error "LuCI forwading is only available if enviroment variable is set to LAN_IF: 'veth'"
  fi
fi
