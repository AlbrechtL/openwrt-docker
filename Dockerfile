########################################################################################################################
# Build stage for rust backend
########################################################################################################################

FROM rust:alpine AS build-backend

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
# Build stage for angular frontend
########################################################################################################################

FROM node:latest AS build-frontend

WORKDIR /usr/local/app
COPY ./web-frontend /usr/local/app/

# See https://github.com/nodejs/docker-node/issues/1668
RUN npm update -g npm
RUN npm ci --no-audit --maxsockets 1

RUN npm install
RUN npm run build -- "--base-href='./'"

########################################################################################################################
# OpenWrt image
########################################################################################################################
FROM alpine:latest

ARG OPENWRT_VERSION="24.10.0"
ARG TARGETPLATFORM
ARG OPENWRT_ROOTFS_IMG
ARG OPENWRT_KERNEL
ARG OPENWRT_ROOTFS_TAR

# Configure Alpine
RUN echo "Building for platform '$TARGETPLATFORM'" \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        CPU_ARCH="x86_64"; \
        APK_EXTRA="ovmf"; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        CPU_ARCH="aarch64"; \
        APK_EXTRA=""; \
    else \
        echo "Error: CPU architecture $TARGETPLATFORM is not supported"; \
        exit 1; \
    fi \
    && apk add --no-cache \
        multirun \
        bash \
        wget \
        grep \
        qemu-system-"$CPU_ARCH" \
        qemu-hw-usb-host \
        qemu-hw-usb-redirect \
        nginx \
        nginx-mod-stream \
        netcat-openbsd \
        uuidgen \
        usbutils \
        pciutils \
        openssh-client \
        util-linux-misc \
        iproute2  \
        "$APK_EXTRA" \
    # It seems that PROFINET packages are not forwarded correctly without the package iproute2. The reason is unknown. \
    && sed -i 's/^worker_processes.*/worker_processes 1;daemon off;/' /etc/nginx/nginx.conf

COPY ./openwrt_additional /var/vm/openwrt_additional

# Handle different CPUs architectures and choose the correct OpenWrt images
RUN echo "Building for platform '$TARGETPLATFORM'" \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
            OPENWRT_IMAGE="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-x86-64-generic-squashfs-combined-efi.img.gz"; \
        elif [ "$OPENWRT_VERSION" = "24.10-SNAPSHOT" ]; then \
            wget https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/x86/64/version.buildinfo; \
            VERSION_BUILDINFO=`cat version.buildinfo`; \
            OPENWRT_IMAGE="https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/x86/64/openwrt-24.10-snapshot-${VERSION_BUILDINFO}-x86-64-generic-squashfs-combined-efi.img.gz"; \
        else \
            OPENWRT_IMAGE="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-squashfs-combined-efi.img.gz"; \
        fi; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        if [ "$OPENWRT_VERSION" = "master" ]; then \
          OPENWRT_IMAGE="https://downloads.openwrt.org/snapshots/targets/armsr/armv8/openwrt-armsr-armv8-generic-squashfs-combined-efi.img.gz"; \
        elif [ "$OPENWRT_VERSION" = "24.10-SNAPSHOT" ]; then \
            wget https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/armsr/armv8/version.buildinfo; \
            VERSION_BUILDINFO=`cat version.buildinfo`; \
            OPENWRT_IMAGE="https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets/armsr/armv8/openwrt-24.10-snapshot-${VERSION_BUILDINFO}-armsr-armv8-generic-squashfs-combined-efi.img.gz"; \
        else \
            OPENWRT_IMAGE="https://archive.openwrt.org/releases/${OPENWRT_VERSION}/targets/armsr/armv8/openwrt-${OPENWRT_VERSION}-armsr-armv8-generic-squashfs-combined-efi.img.gz"; \
        fi; \
    else \
        echo "Error: CPU architecture $TARGETPLATFORM is not supported"; \
        exit 1; \
    fi \
    \
    # Get OpenWrt images  \
    && wget $OPENWRT_IMAGE -O /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz \
    && gzip -d /var/vm/squashfs-combined-${OPENWRT_VERSION}.img.gz \
    \
    # Each CPU architecture needs a different SSH port to make a possible to make a parallel build \
    && SSH_PORT=1022 \
    \
    # Boot OpenWrt in order to install additional packages and settings \
    && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        SSH_PORT=1022; \
        qemu-system-x86_64 -M pc -nographic -nodefaults -m 256 \
        -bios /usr/share/ovmf/bios.bin \
        -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/squashfs-combined-${OPENWRT_VERSION}.img \
        -device virtio-blk-pci,drive=hd0 \
        -device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24,hostfwd=tcp::$SSH_PORT-192.168.1.1:22 \
        -device virtio-net,netdev=qwan0 -netdev user,id=qwan0 \
        & QEMU_PID=$!; \
    else \
        SSH_PORT=2022; \
        qemu-system-aarch64 -M virt -cpu cortex-a53 -nographic -nodefaults -m 256 \
        -bios /usr/share/qemu/edk2-aarch64-code.fd \
        -blockdev driver=raw,node-name=hd0,cache.direct=on,file.driver=file,file.filename=/var/vm/squashfs-combined-${OPENWRT_VERSION}.img \
        -device virtio-blk-pci,drive=hd0 \
        -device virtio-net,netdev=qlan0 -netdev user,id=qlan0,net=192.168.1.0/24,hostfwd=tcp::$SSH_PORT-192.168.1.1:22 \
        -device virtio-net,netdev=qwan0 -netdev user,id=qwan0 \
        & QEMU_PID=$!; \
    fi \
    && echo "QEMU started with PID $QEMU_PID" \
    \
    # OpenWrt master uses apk insted of opkg \
    && if [ "$OPENWRT_VERSION" = "master" ]; then \
        PACKAGE_UPDATE="apk update"; \
        PACKAGE_INSTALL="apk add"; \
        PACKAGE_REMOVE="apk del"; \
        PACKAGE_EXTRA="libudev-zero"; \
    else \
        PACKAGE_UPDATE="opkg update"; \
        PACKAGE_INSTALL="opkg install"; \
        PACKAGE_REMOVE="opkg remove"; \
        PACKAGE_EXTRA=""; \
    fi \
    \
    # Wait for OpenWrt startup and update repo \
    && until ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new root@localhost -p $SSH_PORT "cat /etc/banner"; do echo "Waiting for OpenWrt boot ..."; sleep 1; done \
    # Update package repo. Some some reasons it can fail. So try it until we are successfull. \
    && until ssh root@localhost -p $SSH_PORT "${PACKAGE_UPDATE}"; do echo "Retrying ${PACKAGE_UPDATE} ..."; sleep 1; done\
    # Download Luci, qemu guest agent and mDNS support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} qemu-ga luci luci-ssl umdns losetup ${PACKAGE_EXTRA}" \
    # Download USB, PCI and PCIe support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} usbutils pciutils" \
    # Download Wi-Fi access point support and Wi-Fi USB devices support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} hostapd wpa-supplicant kmod-mt7921u" \
    # Download celluar network support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} modemmanager kmod-usb-net-qmi-wwan luci-proto-modemmanager qmi-utils" \
    # Download basic GPS support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} kmod-usb-serial minicom gpsd" \
    # Add Wireguard support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} wireguard-tools luci-proto-wireguard" \
    # Add Power off script support \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL} luci-app-advanced-reboot" \
    \
    # Add default network config \
    && ssh root@localhost -p $SSH_PORT "uci set network.lan.ipaddr='172.31.1.1'; uci commit network" \
    \
    # Add some files \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_INSTALL}  openssh-sftp-server" \
    && chmod +x /var/vm/openwrt_additional/usr/bin/* \
    && scp -P $SSH_PORT /var/vm/openwrt_additional/usr/bin/* root@localhost:/usr/bin \
    && ssh root@localhost -p $SSH_PORT "${PACKAGE_REMOVE} openssh-sftp-server" \
    \
    # Sync changes into image and shutdown qemu \
    && ssh root@localhost -p $SSH_PORT 'sync; halt' \
    && while kill -0 $QEMU_PID 2>/dev/null; do echo "Waiting for qemu exit ..."; sleep 1; done \
    \
    && gzip /var/vm/squashfs-combined-${OPENWRT_VERSION}.img \
    \
    && echo "OPENWRT_VERSION=\"${OPENWRT_VERSION}\"" > /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_IMAGE_CREATE_DATETIME=\"`date`\"" >> /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_IMAGE_ID=\"`uuidgen`\"" >> /var/vm/openwrt_metadata.conf \
    && echo "OPENWRT_CPU_ARCH=\"${TARGETPLATFORM}\"" >> /var/vm/openwrt_metadata.conf \
    && echo "CONTAINER_CREATE_DATETIME=\"`date`\"" >> /var/vm/openwrt_metadata.conf

COPY --from=build-backend /usr/local/bin/qemu-openwrt-web-backend /usr/local/bin/qemu-openwrt-web-backend
COPY --from=build-frontend /usr/local/app/dist/openwrt-docker-web-gui /var/www/
COPY ./web-frontend/nginx* /var/www/
COPY ./src /run/

RUN chmod +x /run/*.sh

VOLUME /storage
EXPOSE 8006
EXPOSE 8000
EXPOSE 8022

HEALTHCHECK --start-period=10m CMD /run/healthcheck.sh

CMD ["/run/init_container.sh"]
