#!/bin/bash

set -e
set -x

source /etc/gs.conf
wfb_nics=$(echo /sys/class/net/wl* | sed -r -e "s^/sys/class/net/^^g" -e "s/wifi0\s{0,1}//" -e "s/wl\*//")
[ -n "$wfb_integrated_wnic" ] && wfb_nics="$wfb_integrated_wnic $wfb_nics"
[ -z "$wfb_nics" ] && exit 0

monitor_wnic() {
	# Unmanage USB WiFi from NetworkManager
	# [ -f /etc/network/interfaces.d/wfb-$1 ] || echo -e "allow-hotplug $1\niface $1 inet manual" > /etc/network/interfaces.d/wfb-$1
	# if ! nmcli device show $1 | grep -q '(unmanaged)'; then
	# 	nmcli device set $1 managed no
	# 	sleep 1
	# fi
	[[ "$wfb_bandwidth" == "40" ]] && wfb_bandwidth="40+"

	ip link set $1 down
	iw dev $1 set monitor otherbss
	iw reg set $wfb_region
	ip link set $1 up
	iw dev $1 set channel $wfb_channel HT$wfb_bandwidth
}

set_txpower() {
	local driver_name=$(basename $(readlink /sys/class/net/${1}/device/driver))
	case "$driver_name" in
		"rtl88xxau_wfb")
			iw dev $1 set txpower fixed -${2}
			;;
		"8812eu" | "rtl88x2cu" | "8733bu")
			iw dev $1 set txpower fixed $2
			;;
		*)
			echo "not set txpower for $1"
			;;
		esac
}

if [ "$wfb_mode" == "cluster" ]; then
	[ -h "/run/systemd/units/invocation:gs.service" ] || exit 0
	# stop local_node.service if exist
	[ -h "/run/systemd/units/invocation:local_node.service" ] && systemctl stop local_node.service
	# set all wnic to monitor
	for wnic in $wfb_nics; do
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
bandwidth = 20

[gs_video]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_video}'

[base]
bandwidth = ${wfb_bandwidth}

[gs_tunnel]
bandwidth = 20

EOF
# Direct use wfb_rx for msposd_gs
	if [[ "$osd_type" == "msposd_gs" && "$msposd_gs_method" == "wfbrx" ]]; then
	cat >> /etc/wifibroadcast.cfg << EOF
[gs]
streams = [{'name': 'video',   'stream_rx': 0x00, 'stream_tx': None, 'service_type': 'udp_direct_rx',  'profiles': ['base', 'gs_base', 'video', 'gs_video']},
           {'name': 'mavlink', 'stream_rx': 0x10, 'stream_tx': 0x90, 'service_type': 'mavlink',        'profiles': ['base', 'gs_base', 'mavlink', 'gs_mavlink']},
           {'name': 'tunnel',  'stream_rx': 0x20, 'stream_tx': 0xa0, 'service_type': 'tunnel',         'profiles': ['base', 'gs_base', 'tunnel', 'gs_tunnel']},
           {'name': 'msp',     'stream_rx': 0x11, 'stream_tx': 0x91, 'service_type': 'udp_proxy',      'profiles': ['base', 'gs_base', 'gs_msp']}
           ]
[gs_msp]
peer = 'connect://127.0.0.1:${msposd_gs_port}'  # outgoing connection
frame_type = 'data'  # Use data or rts frames
fec_k = 1            # FEC K (For tx side. Rx will get FEC settings from session packet)
fec_n = 2            # FEC N (For tx side. Rx will get FEC settings from session packet)
fec_timeout = 0      # [ms], 0 to disable. If no new packets during timeout, emit one empty packet if FEC block is open
fec_delay = 0        # [us], 0 to disable. Issue FEC packets with delay between them.
EOF
	fi
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

# set tx power for each WNIC
if [ -n "$wfb_txpower" ]; then
	for wnic in $wfb_nics; do
		# wait 20s for wnic up to monitor mode
		sleep 20 && set_txpower $wnic $wfb_txpower &
	done
fi
