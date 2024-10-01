#!/bin/bash

source /config/gs.conf
if [[ "$wfb_rx_mode" == "aggregator" && -n $1 ]]; then
	# Unmanage USB WiFi from NetworkManager
	# nmcli device set $1 managed no # This approach sometimes doesn't work?
	[ -f /etc/network/interfaces.d/wfb-$1 ] || echo -e "allow-hotplug $1\niface $1 inet manual" > /etc/network/interfaces.d/wfb-$1

	ip link set $1 down
	iw dev $1 set monitor otherbss
	iw reg set $wfb_region
	ip link set $1 up
	iw dev $1 set channel $wfb_channel HT$wfb_bandwidth

	systemd-run /usr/bin/wfb_rx -f -p $wfb_stream_id_video -c 127.0.0.1 -u $wfb_listen_port_video -i $wfb_link_id $1
	systemd-run /usr/bin/wfb_rx -f -p $wfb_stream_id_telemetry -c 127.0.0.1 -u $wfb_listen_port_telemetry -i $wfb_link_id $1

elif [ "$wfb_rx_mode" == "receiver" ]; then
	# Modify /etc/wifibroadcast.cfg according to gs.conf
	cat > /etc/wifibroadcast.cfg << EOF
[common]
wifi_channel = ${wfb_channel}
wifi_region = '${wfb_region}'

[gs_mavlink]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_telemetry}'

[gs_video]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_video}'

EOF
	wfb_nics=$(echo /sys/class/net/wl* | sed -r -e "s^/sys/class/net/^^g" -e "s/wlan0\s{0,1}//")
	# grep -q "WFB_NICS=\"${wfb_nics}\"" /etc/default/wifibroadcast || echo "WFB_NICS=\"${wfb_nics}\"" > /tmp/wifibroadcast.default
	# Need Fix: udev rule is executed before the bind mount in gs.service, /tmp/{wifibroadcast.cfg,wifibroadcast.default} being empty on boot
	echo "WFB_NICS=\"${wfb_nics}\"" > /etc/default/wifibroadcast
	systemctl restart wifibroadcast@gs
else
	exit 0
fi
