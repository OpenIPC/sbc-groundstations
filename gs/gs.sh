#!/bin/bash

set -e

if [ -f /config/before.txt ]; then
	sleep 15
	setfont /usr/share/consolefonts/CyrAsia-TerminusBold32x16.psf.gz
	cat | tee /dev/ttyFIQ0 /dev/tty1 << EOF

############################### Welcome to SBC Ground Station ##################################
#                                                                                              #
# WARING: Thist is init startup, may take few minuts, system will auto restart when init done. #
# WARING: Do not turn off the power during the initialization process.                         #
#                                                                                              #
################################################################################################

EOF
fi
while [ -f /config/before.txt ]; do sleep 1; done
source /config/gs.conf
need_u_boot_update=0
need_reboot=0

# Create a partition(exfat) to save record videos
[ -d $REC_Dir ] || mkdir -p $REC_Dir
os_dev=$(df / | grep -oP "/dev/.+(?=p\d+)")
if [ ! -b ${os_dev}p4 ]; then
	sgdisk -ge $os_dev
	root_partirion_size=$(parted -s $os_dev p | grep -oP "\d+(?=MB\s*ext4)")
	root_partirion_size_new=$(( root_partirion_size + $rootfs_reserved_space ))
	cat << EOF | parted ---pretend-input-tty $os_dev > /dev/null 2>&1
resizepart 3 ${root_partirion_size_new}MiB
yes
EOF
	resize2fs ${os_dev}p3
	root_partirion_end=$(parted -s $os_dev p | grep rootfs | tr -s ' ' | cut -d ' ' -f 4)
	parted -s $os_dev mkpart videos fat32 ${root_partirion_end} 100%
	mkfs.exfat ${os_dev}p4
fi
# mount /dev/disk/by-partlabel/videos $REC_Dir
mount ${os_dev}p4 $REC_Dir

# dtbo configuration
if [[ "$enable_external_antenna" == "yes" && ! -f /boot/dtbo/radxa-zero3-external-antenna.dtbo && -d /sys/class/net/wlan0 ]]; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled /boot/dtbo/radxa-zero3-external-antenna.dtbo
	need_u_boot_update=1
	need_reboot=1
elif [[ "$enable_external_antenna" != "yes" && -f /boot/dtbo/radxa-zero3-external-antenna.dtbo && -d /sys/class/net/wlan0 ]] ; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled
	need_u_boot_update=1
	need_reboot=1
fi
ftdoverlays_extlinux=$(grep fdtoverlays /boot/extlinux/extlinux.conf | head -n 1)
if [[ -f /boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo && "$ftdoverlays_extlinux" == *rk3566-dwc3-otg-role-switch.dtbo* ]]; then
	echo "dwc3-otg-role-switch dtb overlay is enabled"
else
	dtc -I dts -O dtb -o /boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo /home/radxa/gs/rk3566-dwc3-otg-role-switch.dts
	need_u_boot_update=1
	need_reboot=1
fi
if [[ -f /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo && "$ftdoverlays_extlinux" == *rk3566-hdmi-max-resolution-4k.dtbo* ]]; then
        echo "rk3566-hdmi-max-resolution-4k dtb overlay is enabled"
else
        dtc -I dts -O dtb -o /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo /home/radxa/gs/rk3566-hdmi-max-resolution-4k.dts
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

# some configuration need reboot to take effect
[ "$need_u_boot_update" == "1" ] && u-boot-update
[ "$need_reboot" == "1" ] && reboot

# br0 network configuration
echo "start configure br0"
[ -f /etc/NetworkManager/system-connections/br0.nmconnection ] || nmcli con add type bridge con-name br0 ifname br0 ipv4.method auto ipv4.addresses ${br0_fixed_ip},${br0_fixed_ip2} autoconnect yes
if [[ -f /etc/NetworkManager/system-connections/br0.nmconnection && -n $br0_fixed_ip && -n $br0_fixed_ip2 ]]; then
	# Check whether the configuration in gs.conf is consistent with br0. If not, update it.
	br0_fixed_ip_OS=$(nmcli -g ipv4.addresses con show br0)
	[ "$eth0_fixed_ip_OS" == "${br0_fixed_ip}, ${br0_fixed_ip2}" ] || nmcli con modify br0 ipv4.addresses ${br0_fixed_ip},${br0_fixed_ip2}
fi
[ -f /etc/NetworkManager/system-connections/br0-slave-eth0.nmconnection ] || nmcli con add type bridge-slave con-name br0-slave-eth0 ifname eth0 master br0
[ -f /etc/NetworkManager/system-connections/br0-slave-usb0.nmconnection ] || nmcli con add type bridge-slave con-name br0-slave-usb0 ifname usb0 master br0
ip ro add 224.0.0.0/4 dev br0
echo "br0 configure done"

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

# radxa0 usb gadget network configuration
echo "start configure radxa0 usb gadget network"
gadget_net_fixed_ip_addr=${gadget_net_fixed_ip%/*}
gadget_net_fixed_ip_sub=${gadget_net_fixed_ip%.*}
if [ ! -f /etc/network/interfaces.d/radxa0 ]; then
	cat > /etc/network/interfaces.d/radxa0 << EOF
auto radxa0
allow-hotplug radxa0
iface radxa0 inet static
	address $gadget_net_fixed_ip
	# post-up mount -o remount,ro /home/radxa/Videos && link mass
	# post-down remove mass && mount -o remount,rw /home/radxa/Videos
	up /usr/sbin/dnsmasq --conf-file=/dev/null --no-hosts --bind-interfaces --except-interface=lo --clear-on-reload --strict-order --listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.11,${gadget_net_fixed_ip_sub}.19,12h --dhcp-lease-max=5 --pid-file=/run/dnsmasq-radxa0.pid --dhcp-option=3 --dhcp-option=6
EOF
fi
# radxa0 dnsmasq configuration
if [[ -n $gadget_net_fixed_ip ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	radxa0_fixed_ip_OS=$(grep -oP "(?<=address\s).*" /etc/network/interfaces.d/radxa0)
	[ "$radxa0_fixed_ip_OS" == "${gadget_net_fixed_ip}" ] || sed -i "s^${radxa0_fixed_ip_OS}^${gadget_net_fixed_ip^}" /etc/network/interfaces.d/radxa0
	grep -q "${gadget_net_fixed_ip_addr}" /etc/network/interfaces.d/radxa0 || sed -i "s/--listen-address=.*,12h/--listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.11,${gadget_net_fixed_ip_sub}.20,12h/" /etc/network/interfaces.d/radxa0
fi
echo "radxa0 usb gadget network configure done"

# pwm fan service
[ "$fan_service_enable" == "yes" ] && ( echo "start fan service"; systemd-run --unit=fan /home/radxa/gs/fan.sh )

# Bind mount the wifibroadcast configuration file to the memory file to prevent frequent writing to the memory card and ensure that the original file is not modified
touch /tmp/wifibroadcast.cfg /tmp/wifibroadcast.default
mount --bind /tmp/wifibroadcast.cfg /etc/wifibroadcast.cfg
mount --bind /tmp/wifibroadcast.default /etc/default/wifibroadcast

# Start wfb_rx aggregator on boot if using aggregator mode
if [ "$wfb_rx_mode" == "aggregator" ]; then
	echo "start wfb_rx aggregator in aggregator mode"
        wfb_rx -a $wfb_listen_port_video -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_video 2>&1 > /dev/null &
        wfb_rx -a $wfb_listen_port_telemetry -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_telemetry 2>&1 > /dev/null &
	if [[ "$wfb_integrated_wnic" == "wlan0" && -d /sys/class/net/wlan0 ]]; then
		nmcli device set wlan0 managed no
		/home/radxa/gs/wfb.sh wlan0 &
	fi
fi
echo "run wfb.sh once in standalone mode"
[ "$wfb_rx_mode" == "standalone" ] && /home/radxa/gs/wfb.sh &

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

# samba configuration
grep -q "\[config\]" /etc/samba/smb.conf || cat >> /etc/samba/smb.conf << EOF
[Videos]
   path = /home/radxa/Videos
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root

[config]
   path = /config
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root
EOF

grep -q "$REC_Dir" /etc/samba/smb.conf || sed -i "/\[Videos\]/{n;s|.*|   ${REC_Dir}|;}" /etc/samba/smb.conf

# show wallpaper
sleep 10 && fbi -d /dev/fb0 -a -fitwidth -T 1 --noverbose /home/radxa/gs/wallpaper.png &

# system boot complete, turn red record LED off
gpioset -D $PWR_LED_drive $(gpiofind PIN_${REC_LED_PIN})=0
echo "gs service start completed"

exit 0
