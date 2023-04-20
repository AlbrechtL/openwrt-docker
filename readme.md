<h1 align="center">QEMU for Docker
<br />
<p align="center">
<img src="https://github.com/kroese/docker-qemu/raw/master/.github/logo.png" title="Logo" style="max-width:100%;" width="256" />
</p>

<div align="center">

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

</div></h1>
QEMU in a docker container using KVM acceleration.

## Features

 - KVM acceleration
 - Graceful shutdown

## Usage

Via `docker-compose.yml`

```yaml
version: "3"
services:
    qemu:
        container_name: qemu
        image: kroese/docker-qemu:latest
        environment:
            DISK_SIZE: "16G"
            BOOT: "http://www.example.com/image.iso"
        devices:
            - /dev/kvm
        cap_add:
            - NET_ADMIN                       
        ports:
            - 22:22
        restart: on-failure
        stop_grace_period: 1m        
```

Via `docker run`

```bash
docker run -it --rm -e "BOOT=http://www.example.com/image.iso" --device=/dev/kvm --cap-add NET_ADMIN kroese/docker-qemu:latest
```

## FAQ

  * ### How do I check if my system supports KVM?

    To check if your system supports KVM run these commands:

    ```
    sudo apt install cpu-checker
    sudo kvm-ok
    ```

    If `kvm-ok` returns an error stating KVM acceleration cannot be used, you may need to change your BIOS settings.

  * ### How do I change the bootdisk? ###

    You can modify the `BOOT` setting to specify the URL of any ISO image:

    ```
    environment:
      BOOT: "http://www.example.com/image.iso"
    ```
    
    It will be downloaded only once, during the first run of the container.

  * ### How do I change the size of the data disk? ###

    By default it is 16GB, but to increase it you can modify the `DISK_SIZE` setting in your compose file:

    ```
    environment:
      DISK_SIZE: "16G"
    ```

    To resize the disk to a capacity of 8 terabyte you would use a value of `"8T"` for example.

  * ### How do I change the location of the data disk? ###

    By default it resides inside a docker volume, but to store it somewhere else you can add these lines to your compose file:

    ```
    volumes:
      - /home/user/data:/storage
    ```

    Just replace `/home/user/data` with the path to the folder you want to use for storage.

  * ### How do I change the space reserved by the data disk? ###

    By default the total space for the disk is reserved in advance. If you want to only reserve the space that is actually used by the disk, add these lines:

    ```
    environment:
      ALLOCATE: "N"
    ```

    This might lower performance a bit, since the image file will need to grow every time new data is added to it.

  * ### How do I change the amount of CPU/RAM? ###

    By default a single core and 512MB of RAM is allocated to the container.

    To increase this you can add the following environment variabeles:

    ```
    environment:
      CPU_CORES: "4"
      RAM_SIZE: "2048M"
    ```

  * ### How do I give the container its own IP address?

    By default the container uses bridge networking, and uses the same IP as the docker host. 

    If you want to give it a seperate IP address, create a macvlan network.

    For example:

    ```
    $ docker network create -d macvlan \
        --subnet=192.168.0.0/24 \
        --gateway=192.168.0.1 \
        --ip-range=192.168.0.100/28 \
        -o parent=eth0 vlan
    ```
    Modify these values to match your local subnet. 

    Now change the containers configuration in your compose file:

    ```
    networks:
        vlan:             
            ipv4_address: 192.168.0.100
    ```

    And add the network to the very bottom of your compose file:

    ```
    networks:
        vlan:
            external: true
    ```

    This also has the advantage that you don't need to do any portmapping anymore, because all ports will be fully exposed this way.

    NOTE: Docker does not allow communication between the host and the container in a macvlan network. There are some ways to fix that if needed, but they go beyond the scope of this FAQ.

  * ### How can the container get an IP address via DHCP? ###

    First follow the steps to configure the container for macvlan (see above), and then add the following lines to your compose file:

    ```
    environment:
        DHCP: "Y"
    devices:
        - /dev/vhost-net
    device_cgroup_rules:
        - 'c 510:* rwm'
    ```

    This will make QEMU retrieve an IP from your router. This will not be the same as the macvlan IP of the container, so to determine which one was assigned to QEMU please check the container logfile or use the devices page of your router for example.

    NOTE: The exact cgroup rule may be different than `510` depending on your system, but the correct rule number will be printed to the logfile in case of error.
