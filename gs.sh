#!/bin/bash

source /config/gs.conf

# Auto expand rootfs [ TODO ]
# If the partition has been extended, an expanded file will be created. If the file is detected to exist, the automatic partition extension will be skipped.

# eth0 network configuration
[ -f /etc/NetworkManager/system-connections/eth0.nmconnection ] || nmcli con add type ethernet con-name eth0 ifname eth0 ipv4.method auto ipv4.addresses ${ETH_Fixed_ip},${ETH_Fixed_ip2} autoconnect yes
if [[ -n $ETH_Fixed_ip && -n $ETH_Fixed_ip2 ]]; then
	# Check whether the configuration in gs.conf is consistent with eth0. If not, update it.
	eth0_fixed_ip_OS=$(nmcli -g ipv4.addresses con show eth0)
	[ $eth0_fixed_ip_OS == "${ETH_Fixed_ip}, ${ETH_Fixed_ip2}" ] || nmcli con modify eth0 ipv4.addresses ${ETH_Fixed_ip},${ETH_Fixed_ip2}
fi

# radxa0 usb gadget network configuration
[ $(cat /sys/kernel/debug/usb/fcc00000.dwc3/mode) == "device" ] && systemctl start radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service
[ -f /etc/NetworkManager/system-connections/radxa0.nmconnection ] || nmcli con add type ethernet con-name radxa0 ifname radxa0 ipv4.method auto ipv4.addresses ${gadget_net_fixed_ip} autoconnect yes
if [[ -n $gadget_net_fixed_ip ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	radxa0_fixed_ip_OS=$(nmcli -g ipv4.addresses con show radxa0)
	[ $radxa0_fixed_ip_OS == "${gadget_net_fixed_ip}" ] || nmcli con modify radxa0 ipv4.addresses ${gadget_net_fixed_ip}
fi

# wlan0 network card configuration
# If no connection named radxa, create one to automatically connect to the unencrypted WiFi named OpenIPC.
[ -f /etc/NetworkManager/system-connections/radxa.nmconnection ] || nmcli con add type wifi ifname wlan0 con-name radxa ssid OpenIPC
# If the WiFi configuration in gs.conf is not empty and changes, modify the WiFi connection information according to the configuration file
if [[ -n $WIFI_SSID && -n $WIFI_Encryption && -n $WIFI_Password ]]; then
	WIFI_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show radxa)
	WIFI_Encryption_OS=$(nmcli -g 802-11-wireless-security.key-mgmt connection show radxa)
	WIFI_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show radxa)
	[[ $WIFI_SSID_OS == $WIFI_SSID && $WIFI_Encryption_OS == $WIFI_Encryption && $WIFI_Password_OS == $WIFI_Password ]] || nmcli con modify radxa ssid ${WIFI_SSID} wifi-sec.key-mgmt ${WIFI_Encryption} wifi-sec.psk ${WIFI_Password}
fi

# Bind mount the wifibroadcast configuration file to the memory file to prevent frequent writing to the memory card and ensure that the original file is not modified
touch /tmp/wifibroadcast.cfg /tmp/wifibroadcast.default
mount --bind /tmp/wifibroadcast.cfg /etc/wifibroadcast.cfg
mount --bind /tmp/wifibroadcast.default /etc/default/wifibroadcast

# Start wfb_rx aggregator on boot if using aggregator mode
if [ $wfb_rx_mode == "aggregator" ]; then
        wfb_rx -a $wfb_listen_port_video -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_video 2>&1 > /dev/null &
        wfb_rx -a $wfb_listen_port_telemetry -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_telemetry 2>&1 > /dev/null &
fi

# If video_on_boot=yes, video playback will be automatically started
[ $video_on_boot == "yes" ] && bash /home/radxa/gs/stream.sh 2>&1 > /dev/null &

exit 0
