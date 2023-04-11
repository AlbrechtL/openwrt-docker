docker-qemu
=============

[![build_img]][build_url]
[![gh_last_release_svg]][qemu-docker-hub]
[![Docker Image Size]][qemu-docker-hub]
[![Docker Pulls Count]][qemu-docker-hub]

[build_url]: https://github.com/kroese/docker-qemu/actions
[qemu-docker-hub]: https://hub.docker.com/r/kroese/docker-qemu

[build_img]: https://github.com/kroese/docker-qemu/actions/workflows/build.yml/badge.svg
[Docker Image Size]: https://img.shields.io/docker/image-size/kroese/docker-qemu/latest
[Docker Pulls Count]: https://img.shields.io/docker/pulls/kroese/docker-qemu.svg?style=flat
[gh_last_release_svg]: https://img.shields.io/docker/v/kroese/docker-qemu?arch=amd64&sort=date

A docker container of QEMU

## Features

 - KVM acceleration
 - Graceful shutdown

## Usage

Via `docker-compose.yml`

```yaml
version: "3"
services:
    vm:
        container_name: dsm
        image: kroese/docker-qemu:latest
        environment:
            DISK_SIZE: "16G"
        devices:
            - /dev/kvm
        cap_add:
            - NET_ADMIN                       
        ports:
            - 5000:5000
            - 5001:5001
        restart: on-failure
        stop_grace_period: 60s
```

Via `docker run`

```bash
docker run -p 5000:5000 --device=/dev/kvm --cap-add NET_ADMIN --stop-timeout 60 kroese/docker-qemu:latest
```

## FAQ

  * ### How do I change the size of the virtual disk? ###

    By default it is 16GB, but you can modify the `DISK_SIZE` setting in your compose file:

    ```
    environment:
      DISK_SIZE: "16G"
    ```

    To create an empty disk with a maximum capacity of 8 terabyte you would use a value of `"8T"` for example.

  * ### How do I change the location of the virtual disk? ###

    By default it resides inside a docker volume, but you can add these lines to your compose file:

    ```
    volumes:
      - /home/user/data:/storage
    ```

    Just replace `/home/user/data` with the path to the folder you want to use for storage.

  * ### How do I give the container a dedicated IP address?

    By default the container uses bridge networking, and is reachable by the IP of the docker host. 

    If you want to give it a seperate IP address, create a macvlan network that matches your local subnet:

    ```
    $ docker network create -d macvlan \
        --subnet=192.168.0.0/24 \
        --gateway=192.168.0.1 \
        --ip-range=192.168.0.100/28 \
        -o parent=eth0 vlan
    ```
    And change the network of the container to `vlan` in your run command:

    ```
     --network vlan --ip=192.168.0.100
    ```

    This has the advantage that you don't need to do any portmapping anymore.

  * ### How do I change the amount of CPU/RAM? ###

    By default an amount of 512MB RAM and 1 vCPU is allocated to the container.

    To increase this you can add the following environment variabeles:

    ```
    environment:
      CPU_CORES: "4"
      RAM_SIZE: "2048M"
    ```
    
  * ### How do I install a specific version of vDSM? ###

    By default it installs vDSM 7.2, but if you want to use an older version you can add its URL to your compose file:

    ```
    environment:
      URL: "https://global.synologydownload.com/download/DSM/release/7.0.1/42218/DSM_VirtualDSM_42218.pat"
    ```

    You can also switch back and forth between versions this way without loosing your file data.
