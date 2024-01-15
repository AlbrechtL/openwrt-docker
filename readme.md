<h1 align="center">QEMU for Docker<br />
<div align="center">
<img src="https://github.com/qemus/qemu-docker/raw/master/.github/logo.png" title="Logo" style="max-width:100%;" width="128" />
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Pulls]][hub_url]

</div></h1>

QEMU in a docker container for running x64 virtual machines (even on ARM platforms).

It uses high-performance QEMU options (like KVM acceleration, kernel-mode networking, IO threading, etc) to achieve near-native speed.

## Features

 - Multi-platform
 - KVM acceleration
 - Web-based viewer

## Usage

Via `docker-compose.yml`

```yaml
version: "3"
services:
  qemu:
    container_name: qemu
    image: qemux/qemu-docker:latest
    environment:
      DISPLAY: "vnc"
      BOOT: "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
    ports:
      - 2222:22
      - 5900:5900
    stop_grace_period: 2m
    restart: unless-stopped
```

Via `docker run`

```bash
docker run -it --rm -e "DISPLAY=vnc" -e "BOOT=http://example.com/image.iso" -p 5900:5900 --device=/dev/kvm --cap-add NET_ADMIN qemux/qemu-docker:latest
```

## FAQ

  * ### How do I specify the boot disk?

    You can modify the `BOOT` environment variable to specify the URL of an ISO image:

    ```yaml
    environment:
      BOOT: "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso"
    ```
    
    It will be downloaded only once, during the initial run of the container.

    Alternatively, you can place a file called ```boot.img``` in the ```/storage``` folder if you want to use a local image instead.

  * ### How do I interact with the VM?

    If you just need text-based output you can use the Docker console, or connect via SSH.

    If you need graphical output, you can enable VNC by adding the following lines to your compose file:

    ```yaml
    environment:
      DISPLAY: "vnc"
    ports:
      - 5900:5900
    ```

    If you want to enable the web-based VNC viewer, so that you do not need to install any client software, add the following lines to your compose file instead:

    ```yaml
    environment:
      DISPLAY: "web"
    ports:
      - 8006:8006
    ```

    Afterwards you can visit  [http://localhost:8006/](http://localhost:8006/) using any webbrowser to view the screen of the VM and interact with it via the keyboard/mouse.

  * ### How do I increase the amount of CPU or RAM?

    By default, a single CPU core and 1 GB of RAM are allocated to the container.

    To increase this, add the following environment variables:

    ```yaml
    environment:
      RAM_SIZE: "4G"
      CPU_CORES: "4"
    ```

  * ### How do I change the size of the data disk?

    To expand the default size of 16 GB, add the `DISK_SIZE` setting to your compose file and set it to your preferred capacity:

    ```yaml
    environment:
      DISK_SIZE: "128G"
    ```
    
    This can also be used to resize the existing disk to a larger capacity without any data loss.
    
  * ### How do I change the location of the data disk?

    To change the location of the data disk, include the following bind mount in your compose file:

    ```yaml
    volumes:
      - /var/qemu:/storage
    ```

    Replace the example path `/var/qemu` with the desired storage folder.

  * ### How do I boot Windows?

    This container is mainly focussed on emulating Linux-based operating systems.

    For emulating Windows there is [dockur/windows](https://github.com/dockur/windows), which is dedicated to that purpose. It has the same features as this container, but additionally includes a TPM emulator, all the necessary drivers, and it will even automaticly download the correct ISO file from the Microsoft servers.

  * ### How do I verify if my system supports KVM?

    To verify if your system supports KVM, run the following commands:

    ```bash
    sudo apt install cpu-checker
    sudo kvm-ok
    ```

    If you receive an error from `kvm-ok` indicating that KVM acceleration can't be used, check the virtualization settings in the BIOS.

  * ### How do I assign an individual IP address to the container?

    By default, the container uses bridge networking, which shares the IP address with the host. 

    If you want to assign an individual IP address to the container, you can create a macvlan network as follows:

    ```bash
    docker network create -d macvlan \
        --subnet=192.168.0.0/24 \
        --gateway=192.168.0.1 \
        --ip-range=192.168.0.100/28 \
        -o parent=eth0 vlan
    ```
    
    Be sure to modify these values to match your local subnet. 

    Once you have created the network, change your compose file to look as follows:

    ```yaml
    services:
      qemu:
        container_name: qemu
        ..<snip>..
        networks:
          vlan:
            ipv4_address: 192.168.0.100

    networks:
      vlan:
        external: true
    ```
   
    An added benefit of this approach is that you won't have to perform any port mapping anymore since all ports will be exposed by default.

    Please note that this IP address won't be accessible from the Docker host due to the design of macvlan, which doesn't permit communication between the two. If this is a concern, you need to create a [second macvlan](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/#host-access) as a workaround.

  * ### How can the VM acquire an IP address from my router?

    After configuring the container for macvlan (see above), it is possible for the VM to become part of your home network by requesting an IP from your router, just like your other devices.

    To enable this feature, add the following lines to your compose file:

    ```yaml
    environment:
      DHCP: "Y"
    device_cgroup_rules:
      - 'c *:* rwm'
    ```

    Please note that in this mode, the container and the VM will each have their own separate IP's. The container will keep the macvlan IP, and the VM will be reachable via the DHCP IP.

  * ### How do I boot with UEFI?

    To enable UEFI booting, add the following line to your compose file:

    ```yaml
    environment:
      BOOT_MODE: "uefi"
    ```

  * ### How do I provide custom arguments to QEMU?

    You can create the `ARGUMENTS` environment variable to provide additional arguments to QEMU at runtime:

    ```yaml
    environment:
      ARGUMENTS: "-device usb-tablet"
    ```

[build_url]: https://github.com/qemus/qemu-docker/
[hub_url]: https://hub.docker.com/r/qemux/qemu-docker/
[tag_url]: https://hub.docker.com/r/qemux/qemu-docker/tags

[Build]: https://github.com/qemus/qemu-docker/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/qemux/qemu-docker/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/qemux/qemu-docker.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/qemux/qemu-docker/latest?arch=amd64&sort=semver&color=066da5
