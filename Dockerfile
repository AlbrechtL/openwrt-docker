FROM alpine:latest

ARG NOVNC_VERSION="1.4.0" 
ARG OPENWRT_VERSION="23.05.1"
ARG VERSION_ARG "0.1"

RUN apk add --no-cache \
        bash \
        tini \
        wget \
        qemu-system-aarch64 \
        qemu-hw-usb-host \
        qemu-hw-usb-redirect \
        nginx \
    && mkdir -p /usr/share/novnc \
    && wget https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz -O /tmp/novnc.tar.gz -q \
    && tar -xf /tmp/novnc.tar.gz -C /tmp/ \
    && cd /tmp/noVNC-${NOVNC_VERSION}\
    && mv app core vendor package.json *.html /usr/share/novnc \
    && sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf


# Get OpenWrt images
RUN  mkdir /var/vm \
    && wget "https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-ext4-rootfs.img.gz" \
    -O /var/vm/rootfs-${OPENWRT_VERSION}.img.gz \
    && wget "https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-kernel.bin" \
    -O /var/vm/kernel.bin
ENV OPENWRT_VERSION=${OPENWRT_VERSION}

COPY ./src /run/
COPY ./web /var/www/
COPY ./openwrt_additional /var/vm/openwrt_additional

RUN chmod +x /run/*.sh
RUN mv /var/www/nginx.conf /etc/nginx/http.d/web.conf

VOLUME /storage
EXPOSE 8006
EXPOSE 8000

RUN echo "$VERSION_ARG" > /run/version

ENTRYPOINT ["/sbin/tini", "-s", "/run/entry.sh"]
