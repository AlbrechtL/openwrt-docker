#!/bin/sh

uci -q delete firewall.ssh
uci set firewall.ssh="rule"
uci set firewall.ssh.name="Allow-SSH"
uci set firewall.ssh.src="wan"
uci set firewall.ssh.dest_port="22"
uci set firewall.ssh.proto="tcp"
uci set firewall.ssh.target="ACCEPT"
uci commit firewall
/etc/init.d/firewall restart