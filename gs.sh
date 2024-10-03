#!/bin/bash

source /config/gs.conf
need_u_boot_update=0
need_reboot=0

[ -d $REC_Dir ] || mkdir -p $REC_Dir
# Auto expand rootfs [ TODO ]
# If the partition has been extended, an expanded file will be created. If the file is detected to exist, the automatic partition extension will be skipped.

# dtbo configuration
ftdoverlays_extlinux=$(grep fdtoverlays /boot/extlinux/extlinux.conf | head -n 1)
[[ -f /boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo && "$ftdoverlays_extlinux" == *rk3566-dwc3-otg-role-switch.dtbo* ]] || ( dtc -I dts -O dtb -o /boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo /home/radxa/gs/rk3566-dwc3-otg-role-switch.dts; need_u_boot_update=1; need_reboot=1 )
dtbo_enable_array=($dtbo_enable_list)
for dtbo in "${dtbo_enable_array[@]}"; do
	[ -f /boot/dtbo/rk3568-${dtbo}.dtbo.disabled ] && ( mv /boot/dtbo/rk3568-${dtbo}.dtbo.disabled /boot/dtbo/rk3568-${dtbo}.dtbo; need_u_boot_update=1; need_reboot=1 )
done

# eth0 network configuration
[ -f /etc/NetworkManager/system-connections/eth0.nmconnection ] || nmcli con add type ethernet con-name eth0 ifname eth0 ipv4.method auto ipv4.addresses ${ETH_Fixed_ip},${ETH_Fixed_ip2} autoconnect yes
if [[ -n $ETH_Fixed_ip && -n $ETH_Fixed_ip2 ]]; then
	# Check whether the configuration in gs.conf is consistent with eth0. If not, update it.
	eth0_fixed_ip_OS=$(nmcli -g ipv4.addresses con show eth0)
	[ "$eth0_fixed_ip_OS" == "${ETH_Fixed_ip}, ${ETH_Fixed_ip2}" ] || nmcli con modify eth0 ipv4.addresses ${ETH_Fixed_ip},${ETH_Fixed_ip2}
fi

# wlan0 network card configuration
# If no connection named radxa, create one to automatically connect to the unencrypted WiFi named OpenIPC.
[ -f /etc/NetworkManager/system-connections/wlan0.nmconnection ] || nmcli con add type wifi ifname wlan0 con-name wlan0 ssid OpenIPC
# If the WiFi configuration in gs.conf is not empty and changes, modify the WiFi connection information according to the configuration file
if [[ -n $WIFI_SSID && -n $WIFI_Encryption && -n $WIFI_Password ]]; then
	WIFI_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show wlan0)
	WIFI_Encryption_OS=$(nmcli -g 802-11-wireless-security.key-mgmt connection show wlan0)
	WIFI_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show wlan0)
	[[ "$WIFI_SSID_OS" == "$WIFI_SSID" && "$WIFI_Encryption_OS" == "$WIFI_Encryption" && "$WIFI_Password_OS" == "$WIFI_Password" ]] || nmcli con modify wlan0 ssid ${WIFI_SSID} wifi-sec.key-mgmt ${WIFI_Encryption} wifi-sec.psk ${WIFI_Password}
fi

# radxa0 usb gadget network configuration
if [ ! -f /etc/network/interfaces.d/radxa0 ]; then
	cat > /etc/network/interfaces.d/radxa0 << EOF
auto radxa0
allow-hotplug radxa0
iface radxa0 inet static
	address $gadget_net_fixed_ip
	# post-up mount -o remount,ro /home/radxa/Videos && link mass
	# post-down remove mass && mount -o remount,rw /home/radxa/Videos
EOF
fi
if [[ -n $gadget_net_fixed_ip ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	radxa0_fixed_ipinfo_OS=$(cat /etc/network/interfaces.d/radxa0 | grep address)
	radxa0_fixed_ip_OS=${radxa0_fixed_ipinfo_OS##* }
	[ "$radxa0_fixed_ip_OS" == "${gadget_net_fixed_ip}" ] || sed -i "s^${radxa0_fixed_ip_OS}^${gadget_net_fixed_ip^g}" /etc/network/interfaces.d/radxa0
fi

# usb0 RNDIS network configuration
[ -f /etc/NetworkManager/system-connections/usb0.nmconnection ] || nmcli con add type ethernet con-name usb0 ifname usb0 ipv4.method auto ipv4.addresses ${usb0_fixed_ip} autoconnect yes
if [[ -n $usb0_fixed_ip ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	usb0_fixed_ip_OS=$(nmcli -g ipv4.addresses con show usb0)
	[ "$usb0_fixed_ip_OS" == "${usb0_fixed_ip}" ] || nmcli con modify usb0 ipv4.addresses ${usb0_fixed_ip}
fi

# pwm fan service
[ "$fan_service_enable" == "yes" ] && systemd-run --unit=fan /home/radxa/gs/fan.sh

# Bind mount the wifibroadcast configuration file to the memory file to prevent frequent writing to the memory card and ensure that the original file is not modified
touch /tmp/wifibroadcast.cfg /tmp/wifibroadcast.default
mount --bind /tmp/wifibroadcast.cfg /etc/wifibroadcast.cfg
mount --bind /tmp/wifibroadcast.default /etc/default/wifibroadcast

# Start wfb_rx aggregator on boot if using aggregator mode
if [ "$wfb_rx_mode" == "aggregator" ]; then
        wfb_rx -a $wfb_listen_port_video -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_video 2>&1 > /dev/null &
        wfb_rx -a $wfb_listen_port_telemetry -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_telemetry 2>&1 > /dev/null &
fi

# If video_on_boot=yes, video playback will be automatically started
[ "$video_on_boot" == "yes" ] && systemd-run --unit=stream /home/radxa/gs/stream.sh
[[ "$otg_mode" == "device" && "$(cat /sys/kernel/debug/usb/fcc00000.dwc3/mode)" == "host" ]] && echo device > /sys/kernel/debug/usb/fcc00000.dwc3/mode
# if otg mode is device, start adbd and ncm on boot
[ "$(cat /sys/kernel/debug/usb/fcc00000.dwc3/mode)" == "device" ] && systemctl start radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service

[ "$need_u_boot_update" == "1" ] && u-boot-update
[ "$need_reboot" == "1" ] && reboot

# system boot complete, turn red record LED off
gpioset -D $PWR_LED_drive $(gpiofind PIN_${REC_LED_PIN})=0

exit 0
