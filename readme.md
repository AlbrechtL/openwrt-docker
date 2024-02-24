# OpenWrt qemu docker container for arm64

QEMU in a docker container for running arm64 virtual machines. Tested on Raspberry Pi 5 but should work on any ARM64 (aarch64) based hardware. It uses high-performance QEMU options (like KVM acceleration, kernel-mode networking, IO threading, etc.) to achieve near-native speed.

Images can be found a docker hub https://hub.docker.com/r/albrechtloh/qemu-openwrt

## Features

 - KVM acceleration
 - Web-based viewer for tty console
 - Attaches two physical Ethernet interfaces exclusively into the docker container
 - USB passthrough e.g. for modem or Wi-Fi
 - Automatic config migration when OpenWrt is updated (experimental)

## Usage

See `docker-compose.yml`

## Build and run

```bash
docker build -t openwrt-docker-arm64 . && docker compose up
```

If you like to specify a specific OpenWrt version you can do
```bash
docker build -t openwrt-docker-arm64 . --build-arg OPENWRT_VERSION="23.05.2" && docker compose up
```
or for the latest development master
```bash
docker build -t openwrt-docker-arm64 . --build-arg OPENWRT_VERSION="master" && docker compose up
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
