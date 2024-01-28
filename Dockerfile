FROM debian:trixie-slim

ARG DEBCONF_NOWARNINGS "yes"
ARG DEBIAN_FRONTEND "noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN "true"

RUN apt-get update \
    && apt-get --no-install-recommends -y install \
        tini \
        wget \
        ovmf \
        nginx \
        swtpm \
        procps \
        apt-utils \
        net-tools \
        qemu-utils \
        ca-certificates \
        qemu-system-aarch64 \
        qemu-efi-aarch64 \
        ipxe-qemu \
        seabios \
        iputils-ping \
        iptables \
        iproute2 \
        isc-dhcp-client \
    && apt-get clean \
    && novnc="1.4.0" \
    && mkdir -p /usr/share/novnc \
    && wget https://github.com/novnc/noVNC/archive/refs/tags/v"$novnc".tar.gz -O /tmp/novnc.tar.gz -q \
    && tar -xf /tmp/novnc.tar.gz -C /tmp/ \
    && cd /tmp/noVNC-"$novnc" \
    && mv app core vendor package.json *.html /usr/share/novnc \
    && unlink /etc/nginx/sites-enabled/default \
    && sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Get OpenWrt images
RUN  mkdir /var/vm \
    && wget "https://archive.openwrt.org/releases/23.05.1/targets/armsr/armv8/openwrt-23.05.1-armsr-armv8-generic-ext4-rootfs.img.gz" \
    -O /var/vm/rootfs.img.gz \
    && wget "https://archive.openwrt.org/releases/23.05.1/targets/armsr/armv8/openwrt-23.05.1-armsr-armv8-generic-kernel.bin" \
    -O /var/vm/kernel.bin

COPY ./src /run/
COPY ./web /var/www/

RUN chmod +x /run/*.sh
RUN mv /var/www/nginx.conf /etc/nginx/sites-enabled/web.conf

VOLUME /storage
EXPOSE 8006
EXPOSE 8000

ARG VERSION_ARG "0.0"
RUN echo "$VERSION_ARG" > /run/version

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
