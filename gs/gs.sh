#!/bin/bash

set -e
set -x

# load config
source /config/gs.conf
need_u_boot_update=0
need_reboot=0

# kernel cmdline configuration
if [[ ${system_wide_screen_mode} == "yes" && ! grep -q "video=HDMI-A-1:" /etc/kernel/cmdline ]]; then
	if [ -z "${screen_mode}" ];then
		echo "waring: screen_mode is not setting in gs.conf"
	else
		sed -i "1s/$/ video=HDMI-A-1:${screen_mode}/" /etc/kernel/cmdline
		need_u_boot_update=1
		need_reboot=1
	fi
elif [[ ${system_wide_screen_mode} == "no" && grep -q "video=HDMI-A-1:" /etc/kernel/cmdline ]]; then
	sed -i 's/ video=HDMI-A-1:[^ ]*//' /etc/kernel/cmdline
else
	echo "error: system_wide_screen_mode must yes or no"
fi

# dtbo configuration
if [[ "$enable_external_antenna" == "yes" && ! -f /boot/dtbo/radxa-zero3-external-antenna.dtbo && -d /sys/class/net/wlan0 ]]; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled /boot/dtbo/radxa-zero3-external-antenna.dtbo
	need_u_boot_update=1
	need_reboot=1
elif [[ "$enable_external_antenna" == "no" && -f /boot/dtbo/radxa-zero3-external-antenna.dtbo && -d /sys/class/net/wlan0 ]] ; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled
	need_u_boot_update=1
	need_reboot=1
fi

dtbo_enable_array=($dtbo_enable_list)
for dtbo in "${dtbo_enable_array[@]}"; do
	if [ -f /boot/dtbo/rk3568-${dtbo}.dtbo.disabled ]; then
		echo "enable ${dtbo}"
		mv /boot/dtbo/rk3568-${dtbo}.dtbo.disabled /boot/dtbo/rk3568-${dtbo}.dtbo
		need_u_boot_update=1
		need_reboot=1
	fi
done

# Update REC_Dir in fstab
[ -d $REC_Dir ] || mkdir -p $REC_Dir
if [ "${REC_Dir}" != "$(grep -oP '(?<=^/dev/mmcblk1p4\t).*?(?=\t)' /etc/fstab)" ]; then
	sed -i "s#^\(/dev/mmcblk1p4\t\)[^\t]*#\1${REC_Dir}#" /etc/fstab
	need_reboot=1
fi

# some configuration need reboot to take effect
[ "$need_u_boot_update" == "1" ] && u-boot-update
[ "$need_reboot" == "1" ] && reboot

# RTC configuration
if [ "$use_external_rtc" == "yes" ]; then
	if [ -c /dev/i2c-4 ]; then
		modprobe i2c-dev
		echo ds3231 0x68 >  /sys/class/i2c-adapter/i2c-4/new_device
		[ -c /dev/rtc1 ] && hwclock -s -f /dev/rtc1 || echo "no ds3231 found"
	else
		echo "i2c-4 is not enabled"
	fi

fi

# Update eth0 configuration
if [[ -f /etc/systemd/network/eth0.network && -n "$eth0_fixed_ip" && -n "$eth0_fixed_ip2" ]]; then
	eth0_fixed_ip_OS=$(grep -m 1 -oP '(?<=Address=).*' /etc/systemd/network/eth0.network)
	eth0_fixed_ip_OS2=$(tac /etc/systemd/network/eth0.network | grep -m 1 -oP '(?<=Address=).*')
	[ "${eth0_fixed_ip_OS}" == "${eth0_fixed_ip}" ] || sed -i "s^${eth0_fixed_ip_OS}^${eth0_fixed_ip}^" /etc/systemd/network/eth0.network
	[ "${eth0_fixed_ip_OS2}" == "${eth0_fixed_ip2}" ] || sed -i "s^${eth0_fixed_ip_OS2}^${eth0_fixed_ip2}^" /etc/systemd/network/eth0.network
	systemctl restart systemd-networkd
fi
echo "eth0 configure done"

# Update br0 configuration
if [[ -f /etc/systemd/network/br0.network && -n "$br0_fixed_ip" ]]; then
	br0_fixed_ip_OS=$(grep -m 1 -oP '(?<=Address=).*' /etc/systemd/network/br0.network)
	[ "${br0_fixed_ip_OS}" == "${br0_fixed_ip}" ] || sed -i "s^${br0_fixed_ip_OS}^${br0_fixed_ip}^" /etc/systemd/network/br0.network
	systemctl restart systemd-networkd
fi
echo "br0 configure done"

# wlan0 configuration
if [ -z "$wfb_integrated_wnic" ]; then
	# managed wlan0 by NetworkManager
	[ -f /etc/network/interfaces.d/wfb-wlan0 ] && rm /etc/network/interfaces.d/wfb-wlan0
	nmcli device | grep -q "^wlan0.*unmanaged.*" && nmcli device set wlan0 managed yes

	# wlan0 station mode configuration
	echo "start configure wlan0 station mode"
	# If no connection named radxa, create one to automatically connect to the unencrypted WiFi named OpenIPC.
	[ -f /etc/NetworkManager/system-connections/wlan0.nmconnection ] || nmcli con add type wifi ifname wlan0 con-name wlan0 ssid OpenIPC
	# If the WiFi configuration in gs.conf is not empty and changes, modify the WiFi connection information according to the configuration file
	if [[ -f /etc/NetworkManager/system-connections/wlan0.nmconnection && -n $WIFI_SSID && -n $WIFI_Encryption && -n $WIFI_Password ]]; then
		WIFI_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show wlan0)
		WIFI_Encryption_OS=$(nmcli -g 802-11-wireless-security.key-mgmt connection show wlan0)
		WIFI_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show wlan0)
		[[ "$WIFI_SSID_OS" == "$WIFI_SSID" && "$WIFI_Encryption_OS" == "$WIFI_Encryption" && "$WIFI_Password_OS" == "$WIFI_Password" ]] || nmcli con modify wlan0 ssid ${WIFI_SSID} wifi-sec.key-mgmt ${WIFI_Encryption} wifi-sec.psk ${WIFI_Password}
	fi
	echo "wlan0 station mode configure done"

	# wlan0 hotspot mode configuration
	echo "start configure wlan0 hotspot mode"
	if [[ -f /etc/NetworkManager/system-connections/hotspot.nmconnection && -n $Hotspot_SSID && -n $Hotspot_Password && -n $Hotspot_ip ]];then
		Hotspot_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show hotspot)
		Hotspot_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show hotspot)
		Hotspot_ip_OS=$(nmcli -g ipv4.addresses con show hotspot)
		[[ "$Hotspot_SSID_OS" == "$Hotspot_SSID" && "$Hotspot_Password_OS" == "$Hotspot_Password" ]] || nmcli connection modify hotspot ssid $Hotspot_SSID wifi-sec.psk $Hotspot_Password
		[[ "$Hotspot_ip_OS" == $Hotspot_ip ]] || nmcli connection modify hotspot ipv4.method shared ipv4.addresses $Hotspot_ip
	elif [[ -d /sys/class/net/wlan0 && -n $Hotspot_SSID && -n $Hotspot_Password && -n $Hotspot_ip ]]; then
		nmcli dev wifi hotspot con-name hotspot ifname wlan0 ssid $Hotspot_SSID password $Hotspot_Password
		nmcli connection modify hotspot ipv4.method shared ipv4.addresses $Hotspot_ip autoconnect no
	else
		echo "no wlan0 or hotspot setting is blank"
	fi
	[[ -d /sys/class/net/wlan0 && "$WIFI_mode" == "hotspot" ]] && ( sleep 15; nmcli connection up hotspot ) &
	echo "wlan0 hotspot mode configure done"
fi

# Update radxa0 dnsmasq configuration
if [[ -f /etc/network/interfaces.d/radxa0 && -n "$gadget_net_fixed_ip" ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	radxa0_fixed_ip_OS=$(grep -oP "(?<=address\s).*" /etc/network/interfaces.d/radxa0)
	[ "$radxa0_fixed_ip_OS" == "${gadget_net_fixed_ip}" ] || sed -i "s^${radxa0_fixed_ip_OS}^${gadget_net_fixed_ip}^" /etc/network/interfaces.d/radxa0
	grep -q "${gadget_net_fixed_ip_addr}" /etc/network/interfaces.d/radxa0 || sed -i "s/--listen-address=.*,12h/--listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.11,${gadget_net_fixed_ip_sub}.20,12h/" /etc/network/interfaces.d/radxa0
fi
echo "radxa0 usb gadget network configure done"

# Update REC_Dir in smb.conf
grep -q "$REC_Dir" /etc/samba/smb.conf || ( sed -i "/\[Videos\]/{n;s|.*|   ${REC_Dir}|;}" /etc/samba/smb.conf && systemctl restart smbd nmbd )

# [ TODO ] Check and Update /etc/wifibroadcast.conf

# pwm fan service
[ "$fan_service_enable" == "yes" ] && ( echo "start fan service"; systemd-run --unit=fan /home/radxa/gs/fan.sh )


# add route to 224.0.0.1
ip ro add 224.0.0.0/4 dev br0
# Start wfb
if [ "$wfb_mode" == "standalone" ]; then
	echo "start wfb in standalone mode"
	# Bind mount the wifibroadcast configuration file
	touch /tmp/wifibroadcast.cfg /tmp/wifibroadcast.default
	mount --bind /tmp/wifibroadcast.cfg /etc/wifibroadcast.cfg
	mount --bind /tmp/wifibroadcast.default /etc/default/wifibroadcast
	/home/radxa/gs/wfb.sh &
elif [ "$wfb_mode" == "cluster" ]; then
	echo "start wfb in cluster mode"
	systemctl start wfb-cluster-manager@gs.service &
	/home/radxa/gs/wfb.sh &
elif [ "$wfb_mode" == "aggregator" ]; then
	echo "start wfb in aggregator mode"
	wfb_rx -a 10000 -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_video 2>&1 > /dev/null &
	wfb_rx -a 10001 -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_mavlink 2>&1 > /dev/null &
	if [[ "$wfb_integrated_wnic" == "wlan0" && -d /sys/class/net/wlan0 ]]; then
		/home/radxa/gs/wfb.sh wlan0 &
	fi
fi

# If video_on_boot=yes, video playback will be automatically started
[ "$video_on_boot" == "yes" ] && ( echo "start stream service"; systemd-run --unit=stream /home/radxa/gs/stream.sh )

# If otg mode is device, start adbd and ncm on boot
if [ "$otg_mode" == "device" ]; then
	echo device > /sys/kernel/debug/usb/fcc00000.dwc3/mode
	( sleep 1 && systemctl start radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service ) &
fi

# start button service
echo "start button service"
systemd-run --unit=button /home/radxa/gs/button.sh

# show wallpaper
sleep 10 && fbi -d /dev/fb0 -a -fitwidth -T 1 --noverbose /home/radxa/gs/wallpaper.png &

# system boot complete, turn red record LED off
gpioset -D $PWR_LED_drive $(gpiofind PIN_${REC_LED_PIN})=0
echo "gs service start completed"

exit 0
