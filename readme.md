# OpenWrt qemu docker container for arm64

Based on the great works of https://github.com/qemus/qemu-docker. Thanks!

QEMU in a docker container for running arm64 virtual machines. Tested on Raspberry Pi 5.

It uses high-performance QEMU options (like KVM acceleration, kernel-mode networking, IO threading, etc.) to achieve near-native speed.

Pre-build images can be found a docker hub (TBD)

## Features

 - KVM acceleration
 - Web-based viewer for tty console
 - Attaches two physical Ethernet interfaces exclusicly into the docker container

## Usage

See `docker-compose.yml`

## How it works
See `src/entry.sh` and `Dockerfile`

## Build and run

```bash
docker build -t openwrt-docker-arm64 . && docker compose up
```
