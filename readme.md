# OpenWrt qemu docker container for arm64 and Weidmueller u-OS

Automated build: [![Build](https://github.com/AlbrechtL/openwrt-docker-arm64-build/actions/workflows/build.yml/badge.svg)](https://github.com/AlbrechtL/openwrt-docker-arm64-build/actions/workflows/build.yml)

OpenWrt in a docker container utilizing qemu. Tested on Raspberry Pi 5 and Weidmueller UC20-M4000 PLC but should work on any ARM64 (aarch64) based hardware. It uses high-performance QEMU options (like KVM acceleration, kernel-mode networking, IO threading, etc.) to achieve near-native speed.

* Docker images can be found a docker hub https://hub.docker.com/r/albrechtloh/qemu-openwrt
* Weidmueller u-OS apps are currently only available via Github Actions https://github.com/AlbrechtL/openwrt-docker-arm64-build/actions

## Features

 - KVM acceleration
 - Web-based viewer for tty console
 - Attaches two physical Ethernet interfaces (LAN/WAN) exclusively into the docker container
 - Create virtual LAN between OpenWrt and host system (LAN only)
 - USB passthrough e.g. for modem or Wi-Fi
 - Automatic config migration when OpenWrt is updated (experimental)

## Pre-installed OpenWrt software packages

Because OpenWrt doesn't provide a user installed package update mechanism all required packages needs to be included into the OpenWrt rootfs image. This Docker images adds the following software to the OpenWrt rootfs:
* Luci Web interface
* ssh server
* Wi-Fi client and access point support
* Wireguard

### Supported USB devices

* Mediathek MT7961AU Wi-Fi 6 AX chipset based devices e.g. (FENVI 1800Mbps WiFi 6 USB Adapter)
* SIMCOM SIM8262E-M2 based devices (Multi-Band 5G NR/LTE-FDD/LTE-TDD/HSPA+ modem)

## Usage

See `docker-compose.yml`

## Build and run

```bash
docker compose up
```

If you like to specify a specific OpenWrt version you can do
```bash
docker build -t openwrt-docker-arm64 . --build-arg OPENWRT_VERSION="23.05.2" && docker compose up
```
or for the latest development master. The `--no-cache` option is necessary to get always the newest version.
```bash
docker build --no-cache -t openwrt-docker-arm64 . --build-arg OPENWRT_VERSION="master" && docker compose up
```

## Screenshots

VNC console in web browser
![VNC console in web browser](pictures/qemu_openwrt_vnc_console.png)

OpenWrt LUCI web interface
![OpenWrt LUCI web interface](pictures/qemu_openwrt_luci.png)

## Acknowledgement

I would like to thanks to following Open Source projects. Without these great work this container would not be possbile
* [OpenWrt](https://openwrt.org/)
* [QEMU](https://www.qemu.org/)
* [qemu-docker](https://github.com/qemus/qemu-docker)
* [noVNC](https://novnc.com/)
* [script-server](https://github.com/bugy/script-server)
* [Docker](https://www.docker.com/)
* [Alpine Linux](https://www.alpinelinux.org/)

## Disclaimer: Security Notice

This software container is a proof of concept and has not undergone comprehensive cybersecurity assessments. Users are cautioned that potential vulnerabilities may exist, posing risks to system security and data integrity. By deploying or using this container, users accept the associated risks, and the developers disclaim any responsibility for security incidents or data breaches. A thorough security evaluation, including penetration testing and compliance checks, is strongly advised before production deployment. The software is provided without warranty, and users are encouraged to provide feedback for collaborative efforts in addressing security concerns. Users acknowledge reading and understanding this disclaimer, assuming responsibility for ensuring their environment's security.
