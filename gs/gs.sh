#!/bin/bash

set -e
set -x

# load config
source /etc/gs.conf

# check and apply configuration in gs.conf
source /gs/gs-applyconf.sh

# RTC
if [ "$use_external_rtc" == "yes" ]; then
	if [ -c /dev/i2c-4 ]; then
		modprobe i2c-dev
		echo ds3231 0x68 >  /sys/class/i2c-adapter/i2c-4/new_device
		( sleep 1 && [ -c /dev/rtc1 ] && hwclock -s -f /dev/rtc1 || echo "no ds3231 found" ) &
	else
		echo "i2c-4 is not enabled"
	fi
fi

# GPS
[ "$use_gps" == "yes" ] && systemctl start chrony gpsd &

# WiFi
if [ -d /sys/class/net/wifi0 ]; then
	if [ "$wifi_mode" == "hotspot" ]; then
	       ( sleep 15; nmcli connection up hotspot ) &
       elif [ "$wifi_mode" == "station" ]; then
	       ( sleep 5; nmcli connection up wifi0 ) &
	fi
fi

# pwm fan service
[ "$fan_service_enable" == "yes" ] && ( echo "start fan service"; systemd-run --unit=fan /gs/fan.sh )

# add route to 224.0.0.1
ip ro add 224.0.0.0/4 dev br0
# Start wfb
if [ "$wfb_mode" == "standalone" ]; then
	echo "start wfb in standalone mode"
	# Bind mount the wifibroadcast configuration file
	touch /tmp/wifibroadcast.cfg /tmp/wifibroadcast.default
	mount --bind /tmp/wifibroadcast.cfg /etc/wifibroadcast.cfg
	mount --bind /tmp/wifibroadcast.default /etc/default/wifibroadcast
	/gs/wfb.sh &
elif [ "$wfb_mode" == "cluster" ]; then
	echo "start wfb in cluster mode"
	systemctl start wfb-cluster-manager@gs.service &
	/gs/wfb.sh &
elif [ "$wfb_mode" == "aggregator" ]; then
	echo "start wfb in aggregator mode"
	wfb_rx -a 10000 -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_video 2>&1 > /dev/null &
	wfb_rx -a 10001 -K $wfb_key -i $wfb_link_id -c $wfb_outgoing_ip -u $wfb_outgoing_port_mavlink 2>&1 > /dev/null &
	if [[ "$wfb_integrated_wnic" == "wifi0" && -d /sys/class/net/wifi0 ]]; then
		/gs/wfb.sh wifi0 &
	fi
fi

# Passing record button state from button.sh to stream.sh
[ -p /run/record_button.fifo ] || mkfifo /run/record_button.fifo

# If video_on_boot=yes, video playback will be automatically started
[ "$video_on_boot" == "yes" ] && ( echo "start stream service"; systemd-run --unit=stream /gs/stream.sh )

# If otg mode is device, start adbd and ncm on boot
if [ "$otg_mode" == "device" ]; then
	echo device > /sys/kernel/debug/usb/fcc00000.dwc3/mode
	( sleep 1 && systemctl start radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service ) &
fi

# start button service
echo "start button service"
systemd-run --unit=button /gs/button.sh

# system boot complete, turn red record LED off
gpioset -D $red_led_drive $(gpiofind PIN_${red_led_pin})=0
echo "gs service start completed"

exit 0
