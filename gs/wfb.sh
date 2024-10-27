#!/bin/bash

set -e
set -x

source /config/gs.conf
wfb_nics=$(echo /sys/class/net/wl* | sed -r -e "s^/sys/class/net/^^g" -e "s/wlan0\s{0,1}//" -e "s/wl\*//")
[ -n "$wfb_integrated_wnic" ] && wfb_nics="$wfb_integrated_wnic $wfb_nics"
[ -z "$wfb_nics" ] && exit 0

monitor_wnic(){
	# Unmanage USB WiFi from NetworkManager
	# [ -f /etc/network/interfaces.d/wfb-$1 ] || echo -e "allow-hotplug $1\niface $1 inet manual" > /etc/network/interfaces.d/wfb-$1
	# if ! nmcli device show $1 | grep -q '(unmanaged)'; then
	# 	nmcli device set $1 managed no
	# 	sleep 1
	# fi

	ip link set $1 down
	iw dev $1 set monitor otherbss
	iw reg set $wfb_region
	ip link set $1 up
	iw dev $1 set channel $wfb_channel HT$wfb_bandwidth
}

if [ "$wfb_mode" == "cluster" ]; then
	[ -h "/run/systemd/units/invocation:gs.service" ] || exit 0
	# stop local_node.service if exist
	[ -h "/run/systemd/units/invocation:local_node.service" ] && systemctl stop local_node.service
	# set all wnic to monitor
	for wnic in $wfb_nics;do
		monitor_wnic $wnic
	done
	# run wfb local_node
	systemd-run --unit=local_node.service bash -c "
	# gs_video
	wfb_rx -f -c 127.0.0.1 -u 10000 -p $wfb_stream_id_video -i 7669206 -R 2097152 $wfb_nics &
	# gs_mavlink
	wfb_rx -f -c 127.0.0.1 -u 10001 -p $wfb_stream_id_mavlink -i 7669206 -R 2097152 $wfb_nics &
	wfb_tx -I 11001 -R 2097152  $wfb_nics &
	# gs_tunnel
	wfb_rx -f -c 127.0.0.1 -u 10002 -p $wfb_stream_id_tunnel -i 7669206 -R 2097152 $wfb_nics &
	wfb_tx -I 11002 -R 2097152 $wfb_nics &
	wait
	"
elif [ "$wfb_mode" == "standalone" ]; then
	[ -h "/run/systemd/units/invocation:gs.service" ] || exit 0
	# Modify /etc/wifibroadcast.cfg according to gs.conf
	cat > /etc/wifibroadcast.cfg << EOF
[common]
wifi_channel = '${wfb_channel}'
wifi_region = '${wfb_region}'

[gs_mavlink]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_mavlink}'

[gs_video]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_video}'

EOF
	# grep -q "WFB_NICS=\"${wfb_nics}\"" /etc/default/wifibroadcast || echo "WFB_NICS=\"${wfb_nics}\"" > /tmp/wifibroadcast.default
	echo "WFB_NICS=\"${wfb_nics}\"" > /etc/default/wifibroadcast
	systemctl restart wifibroadcast@gs
elif [[ "$wfb_mode" == "aggregator" && -n $1 ]]; then
	monitor_wnic $1
	systemd-run /usr/bin/wfb_rx -f -p $wfb_stream_id_video -c 127.0.0.1 -u 10000 -i $wfb_link_id $1
	systemd-run /usr/bin/wfb_rx -f -p $wfb_stream_id_mavlink -c 127.0.0.1 -u 10001 -i $wfb_link_id $1
else
	exit 0
fi
