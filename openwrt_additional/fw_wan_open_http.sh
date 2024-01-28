#!/bin/sh

uci -q delete firewall.http
uci set firewall.http="rule"
uci set firewall.http.name="Allow-HTTP"
uci set firewall.http.src="wan"
uci set firewall.http.dest_port="80"
uci set firewall.http.proto="tcp"
uci set firewall.http.target="ACCEPT"
uci commit firewall
/etc/init.d/firewall restart
