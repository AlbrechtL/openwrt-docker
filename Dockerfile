########################################################################################################################
# Build stage for rust backend
########################################################################################################################

FROM rust:alpine AS builder

ARG TARGETPLATFORM

RUN apk update && \
    apk add --no-cache \
    musl-dev \
    gcc

WORKDIR /usr/src/qemu-backend
COPY ./web-backend .

# Build the application for musl
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        rustup target add aarch64-unknown-linux-musl; \
    else \
        rustup target add x86_64-unknown-linux-musl; \
    fi

# Build the application for the specific target architecture
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        cargo build --release --target aarch64-unknown-linux-musl; \
        cp /usr/src/qemu-backend/target/aarch64-unknown-linux-musl/release/qemu-openwrt-web-backend /usr/local/bin; \
    else \
        cargo build --release --target x86_64-unknown-linux-musl; \
        cp /usr/src/qemu-backend/target/x86_64-unknown-linux-musl/release/qemu-openwrt-web-backend /usr/local/bin; \
    fi

########################################################################################################################
# OpenWrt image
########################################################################################################################
FROM alpine:latest

ARG NOVNC_VERSION="1.5.0" 
ARG OPENWRT_VERSION="23.05.5"
ARG VERSION_ARG="0.1"
ARG TARGETPLATFORM
ARG OPENWRT_ROOTFS_IMG
ARG OPENWRT_KERNEL
ARG OPENWRT_ROOTFS_TAR

# Configure Alpine
RUN echo "Building for platform '$TARGETPLATFORM'" \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        CPU_ARCH="x86_64"; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        CPU_ARCH="aarch64"; \
    else \
        echo "Error: CPU architecture $TARGETPLATFORM is not supported"; \
        exit 1; \
    fi \
    && apk add --no-cache \
        multirun \
        bash \
        wget \
        qemu-system-"$CPU_ARCH" \
        qemu-hw-usb-host \
        qemu-hw-usb-redirect \
        nginx \
        nginx-mod-stream \
        netcat-openbsd \
        tcpdump \
        uuidgen \
        curl \
        usbutils \
        openssh-client \
    && mkdir -p /usr/share/novnc \
    && wget https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz -O /tmp/novnc.tar.gz -q \
    && tar -xf /tmp/novnc.tar.gz -C /tmp/ \
    && cd /tmp/noVNC-${NOVNC_VERSION}\
    && mv app core vendor package.json *.html /usr/share/novnc \
    && sed -i 's/^worker_processes.*/worker_processes 1;daemon off;/' /etc/nginx/nginx.conf
    
# Handle different CPUs architectures and choose the correct OpenWrt images
RUN echo "Building for platform '$TARGETPLATFORM'" \
    OPKG_EXTRA_ARGS="" \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
            OPENWRT_IMAGE="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-generic-squashfs-combined.img.gz"; \
        elif [ "$OPENWRT_VERSION" = "24.10-SNAPSHOT" ]; then \
            wget https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/x86/64/version.buildinfo; \
            VERSION_BUILDINFO=`cat version.buildinfo`; \
            OPENWRT_IMAGE="https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/x86/64/openwrt-24.10-snapshot-${VERSION_BUILDINFO}-x86-64-generic-squashfs-combined.img.gz"; \
        else \
            OPENWRT_IMAGE="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-squashfs-combined.img.gz"; \
        fi; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
          OPENWRT_IMAGE="https://downloads.openwrt.org/snapshots/targets/armsr/armv8/openwrt-armsr-armv8-generic-squashfs-combined.img.gz"; \
        elif [ "$OPENWRT_VERSION" = "24.10-SNAPSHOT" ]; then \
            wget https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/armsr/armv8/version.buildinfo; \
            VERSION_BUILDINFO=`cat version.buildinfo`; \
            OPENWRT_IMAGE="https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/armsr/armv8/openwrt-24.10-snapshot-${VERSION_BUILDINFO}-armsr-armv8-generic-squashfs-combined.img.gz"; \
        else \
            OPENWRT_IMAGE="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-squashfs-combined.img.gz"; \
        fi; \
    else \
        echo "Error: CPU architecture $TARGETPLATFORM is not supported"; \
        exit 1; \
    fi \
    \
    # Get OpenWrt images  \
    && mkdir /var/vm \ 
    && mkdir /var/vm/packages \
    && wget $OPENWRT_IMAGE -O /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz \
    && gzip -d /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz \
    \
    # Boot OpenWrt in order to install additional packages and settings
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \ 
        qemu-system-x86_64 -M pc -smp 2 -nographic -nodefaults -m 256 \
        -bios /usr/share/qemu/edk2-aarch64-code.fd \
        -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/squashfs-combined-${OPENWRT_VERSION}.img \
        -device virtio-blk-pci,drive=hd0 \
        -device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24,hostfwd=tcp::8022-192.168.1.1:22 \
        -device virtio-net,netdev=qwan0 -netdev user,id=qwan0 \
        -daemonize; \
    else \
        qemu-system-aarch64 -M virt -cpu cortex-a53 -smp 2 -nographic -nodefaults -m 256 \
        -bios /usr/share/qemu/edk2-aarch64-code.fd \
        -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/squashfs-combined-${OPENWRT_VERSION}.img \
        -device virtio-blk-pci,drive=hd0 \
        -device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24,hostfwd=tcp::8022-192.168.1.1:22 \
        -device virtio-net,netdev=qwan0 -netdev user,id=qwan0 \
        -daemonize; \
    fi \
    \
    && until ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new root@localhost -p 8022 'opkg update'; do echo "Retrying ssh ..."; sleep 1; done \
    # Download Luci, qemu guest agent and mDNS support \
    && ssh root@localhost -p 8022 'opkg install qemu-ga luci luci-ssl umdns' \
    # Download Wi-Fi access point support and Wi-Fi USB devices support \
    && ssh root@localhost -p 8022 'opkg install hostapd wpa-supplicant kmod-mt7921u' \
    # Download celluar network support \
    && ssh root@localhost -p 8022 'opkg install modemmanager kmod-usb-net-qmi-wwan luci-proto-modemmanager qmi-utils' \
    # Download basic GPS support \ 
    && ssh root@localhost -p 8022 'opkg install kmod-usb-serial usbutils minicom gpsd' \
    # Add Wireguard support \
    && ssh root@localhost -p 8022 'opkg install wireguard-tools luci-proto-wireguard' \
    \
    # Sync changes into image
    && ssh root@localhost -p 8022 'sync' \
    \
    && echo "OPENWRT_VERSION=\"${OPENWRT_VERSION}\"" > /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_IMAGE_CREATE_DATETIME=\"`date`\"" >> /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_IMAGE_ID=\"`uuidgen`\"" >> /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_CPU_ARCH=\"${TARGETPLATFORM}\"" >> /var/vm/openwrt_metadata.conf

COPY --from=builder /usr/local/bin/qemu-openwrt-web-backend /usr/local/bin/qemu-openwrt-web-backend
COPY ./src /run/
COPY ./web-frontend /var/www/
COPY ./openwrt_additional /var/vm/openwrt_additional

RUN chmod +x /run/*.sh

VOLUME /storage
EXPOSE 8006
EXPOSE 8000
EXPOSE 8022

RUN echo "$VERSION_ARG" > /run/version \
    && echo "CONTAINER_CREATE_DATETIME=\"`date`\"" >> /var/vm/openwrt_metadata.conf

HEALTHCHECK --start-period=10m CMD /run/healthcheck.sh

CMD ["/run/init_container.sh"]