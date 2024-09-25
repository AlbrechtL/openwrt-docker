########################################################################################################################
# Build stage for rust backend
########################################################################################################################

FROM --platform=$BUILDPLATFORM rust:alpine as builder

ARG TARGETPLATFORM

RUN apk update && \
    apk add --no-cache \
    musl-dev \
    gcc

WORKDIR /usr/src/qemu-backend
COPY ./web-backend .

# Build the application for musl
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo build --release --target x86_64-unknown-linux-musl \
    && cp /usr/src/qemu-backend/target/x86_64-unknown-linux-musl/release/qemu-openwrt-web-backend /usr/local/bin

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

ARG NOVNC_VERSION="1.4.0" 
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
        uuidgen \
        curl \
        usbutils \
    && mkdir -p /usr/share/novnc \
    && wget https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz -O /tmp/novnc.tar.gz -q \
    && tar -xf /tmp/novnc.tar.gz -C /tmp/ \
    && cd /tmp/noVNC-${NOVNC_VERSION}\
    && mv app core vendor package.json *.html /usr/share/novnc \
    && sed -i 's/^worker_processes.*/worker_processes 1;daemon off;/' /etc/nginx/nginx.conf
    
# Handle different CPUs architectures and choose the correct OpenWrt images
RUN echo "Building for platform '$TARGETPLATFORM'" \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
            OPENWRT_ROOTFS_IMG="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-generic-ext4-rootfs.img.gz"; \
            OPENWRT_KERNEL="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-generic-kernel.bin"; \
            OPENWRT_ROOTFS_TAR="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-rootfs.tar.gz"; \
        else \
            OPENWRT_ROOTFS_IMG="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-rootfs.img.gz"; \
            OPENWRT_KERNEL="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-kernel.bin"; \
            OPENWRT_ROOTFS_TAR="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-rootfs.tar.gz"; \
        fi; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
            OPENWRT_ROOTFS_IMG="https://downloads.openwrt.org/snapshots/targets/armsr/armv8/openwrt-armsr-armv8-generic-ext4-rootfs.img.gz"; \
            OPENWRT_KERNEL="https://downloads.openwrt.org/snapshots/targets/armsr/armv8/openwrt-armsr-armv8-generic-kernel.bin"; \
            OPENWRT_ROOTFS_TAR="https://downloads.openwrt.org/snapshots/targets/armsr/armv8/openwrt-armsr-armv8-rootfs.tar.gz"; \
        else \
            OPENWRT_ROOTFS_IMG="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-ext4-rootfs.img.gz"; \
            OPENWRT_KERNEL="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-kernel.bin"; \
            OPENWRT_ROOTFS_TAR="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-rootfs.tar.gz"; \
        fi; \
    else \
        echo "Error: CPU architecture $TARGETPLATFORM is not supported"; \
        exit 1; \
    fi \
    \
    # Get OpenWrt images  \
    && mkdir /var/vm \ 
    && mkdir /var/vm/packages \
    && echo $OPENWRT_ROOTFS_IMG \
    && wget $OPENWRT_ROOTFS_IMG -O /var/vm/rootfs-${OPENWRT_VERSION}.img.gz \
    && wget "${OPENWRT_KERNEL}" -O /var/vm/kernel.bin \ 
    && wget "${OPENWRT_ROOTFS_TAR}" -O /tmp/rootfs-${OPENWRT_VERSION}.tar.gz \
    \
    # Use OpenWrt rootfs to download additional IPKs and put them into the Docker image \
    && mkdir /tmp/openwrt-rootfs \
    && tar -xzf /tmp/rootfs-${OPENWRT_VERSION}.tar.gz -C /tmp/openwrt-rootfs \
    && cp /etc/resolv.conf /tmp/openwrt-rootfs/etc/resolv.conf \
    && chroot /tmp/openwrt-rootfs mkdir -p /var/lock \
    && chroot /tmp/openwrt-rootfs opkg update \
    # Download Luci and qemu guest agent \
    && chroot /tmp/openwrt-rootfs opkg install qemu-ga luci usbutils --download-only \
    # Download Wi-Fi access point support and Wi-Fi USB devices support \
    && chroot /tmp/openwrt-rootfs opkg install hostapd wpa-supplicant kmod-mt7921u --download-only \
    # Download celluar network support \
    && chroot /tmp/openwrt-rootfs opkg install modemmanager kmod-usb-net-qmi-wwan luci-proto-modemmanager qmi-utils --download-only \
    # Download basic GPS support \ 
    && chroot /tmp/openwrt-rootfs opkg install kmod-usb-serial usbutils minicom gpsd --download-only \
    # Add Wireguard support \
    && chroot /tmp/openwrt-rootfs opkg install wireguard-tools luci-proto-wireguard --download-only \
    # Copy downloaded IPKs into the Docker image \
    && cp /tmp/openwrt-rootfs/*.ipk /var/vm/packages \
    && rm -rf /tmp/openwrt-rootfs \
    && rm /tmp/rootfs-${OPENWRT_VERSION}.tar.gz \
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

CMD ["/run/init_container.sh"]