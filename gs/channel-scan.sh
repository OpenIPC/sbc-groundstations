#!/bin/bash

set -e
echo "start channel scan" > /run/pixelpilot.msg
source /config/gs.conf
[[ "$wfb_bandwidth" == "40" ]] && wfb_bandwidth="40+"

if [ -z "$1" ]; then
	wfb_nics=$(echo /sys/class/net/wl* | sed -r -e "s^/sys/class/net/^^g" -e "s/wifi0\s{0,1}//" -e "s/wl\*//")
	[ -n "$wfb_integrated_wnic" ] && wfb_nics="$wfb_integrated_wnic $wfb_nics"
	if [ -n "$wfb_nics" ]; then
		iface_name=${wfb_nics##* }
	else
		echo "No USB WiFi Found!" > /run/pixelpilot.msg
		exit 0
	fi
else
	iface_name="$1"
	echo "use specified WINC ${iface_name} for scanning"
	if [ ! -d /sys/class/net/${iface_name} ]; then
		echo "no WINC $iface_name found" > /run/pixelpilot.msg
		exit 1
	fi
fi

# make sure WNIC in monitor mode
if iw $iface_name info | grep -q monitor; then
	echo "$iface_name is in monitor mode, start scanning"
else
	echo "$iface_name is not in monitor mode, set to monitor mode"
	ip link set $iface_name down
	iw dev $iface_name set monitor otherbss
	ip link set $iface_name up
fi

# get WINC phy name
iface_phy=$(basename $(readlink /sys/class/net/${iface_name}/phy80211))

# RTL8812AU BUG:
#* Tx set to channel 100, Rx set to channel 132 can receive data
#    + TX: iw dev wlxc8fe0f41d393 set channel 100 HT20
#    + RX: iw dev wlx08107b91b856  set channel 132 HT20
#* Tx set to channel 104, Rx set to channel 136 can receive data
#    + TX: iw dev wlxc8fe0f41d393 set channel 104 HT20
#    + RX: iw dev wlx08107b91b856  set channel 136 HT20

channel_available=$(iw phy $iface_phy info | grep -oP "\s*\*\s5.*\[\K\d+(?=\].*dBm)")
[ $wfb_channel -gt 104 ] && channel_available=$(echo "$channel_available" | sort -nr)
for channel in $channel_available; do
	iw dev $iface_name set channel $channel HT${wfb_bandwidth}
	iface_start_bytes=$(grep -oP "${iface_name}:\s+\d+\s+\K\d+" /proc/net/dev)
	sleep 0.1
	iface_stop_bytes=$(grep -oP "${iface_name}:\s+\d+\s+\K\d+" /proc/net/dev)
	iface_receive_bytes=$(( ${iface_stop_bytes} - ${iface_start_bytes} ))
	echo "channel $channel bytes in 0.1s is: $iface_receive_bytes"
	if [ $iface_receive_bytes -ge 50 ]; then
		if timeout 0.2s tcpdump -i $iface_name -e 'type mgt or type data' -c 5 -s 68 -l 2>/dev/null | grep -q 'SA:57:42'; then
			# Incompatible with wfb cluster and aggregation mode
			# need judge by wfb cli api
			udp_start_bytes=$(grep -oP "^Udp: \K\d+" /proc/net/snmp)
			sleep 0.2
			udp_stop_bytes=$(grep -oP "^Udp: \K\d+" /proc/net/snmp)
			udp_receive_bytes=$(($udp_stop_bytes - $udp_start_bytes))
			if [ $udp_receive_bytes -ge 30 ]; then
				echo "wfb channel found: channel $channel "
				echo "found channel: $channel" > /run/pixelpilot.msg
				channel_wfb_used=$channel
				sed -i "s/wfb_channel='[0-9]\+'/wfb_channel='${channel_wfb_used}'/" /config/gs.conf
				break 
			else
				echo "channel $channel is wfb but key may not matched"
				channel_wfb_used=$channel
			fi
		else
			echo "    * channel $channel have traffic but not wfb"
		fi
	fi
done

if [ -n "${channel_wfb_used}" ]; then
	for nic in $wfb_nics; do
		iw dev $nic set channel $channel_wfb_used HT${wfb_bandwidth}
	done
else
	echo "no channel found" > /run/pixelpilot.msg
fi
