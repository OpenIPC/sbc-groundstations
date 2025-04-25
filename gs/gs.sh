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

# If otg mode is device, start adbd and ncm on boot
if [ "$otg_mode" == "device" ]; then
	echo device > /sys/kernel/debug/usb/fcc00000.dwc3/mode
	( sleep 1 && systemctl start radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service ) &
fi

# pwm fan service
[ "$fan_service_enable" == "yes" ] && ( echo "start fan service"; systemd-run --unit=fan /gs/fan.sh )

# ttyd
if [ "$ttyd_enable" == "yes" ]; then
	[ "$(systemctl is-enabled ttyd)" == "enabled" ] || systemctl enabled --now ttyd
else
	[ "$(systemctl is-enabled ttyd)" == "enabled" ] && systemctl disabled --now ttyd
fi

# If video_on_boot=yes, video playback will be automatically started
if [ "$video_on_boot" == "yes" ]; then
	# Start RubyFpv
	if [ "$video_player" == "rubyfpv" ]; then
		# Load wifi drivers
		[ -d "/sys/module/8812eu" ] || modprobe 8812eu rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0
		[ -d "/sys/module/88XXau_wfb" ] || modprobe 88XXau_wfb rtw_tx_pwr_idx_override=1
		# bind mount Vides dir to ruby
		[ -d "/home/radxa/ruby/media" ] || mkdir -p /home/radxa/ruby/media
		mount --bind $rec_dir /home/radxa/ruby/media
		# Use button gpio settings in gs.conf
		button_gpio="$btn_cr_pin $btn_cl_pin $btn_cu_pin $btn_cd_pin $btn_q1_pin $btn_q2_pin $btn_q3_pin"
		[ "$button_gpio" == "$(< /config/gpio.txt)" ] || echo "$button_gpio" > /config/gpio.txt
		# start rubyfpv
		systemd-run --unit=rubyfpv \
			--property=TTYPath=/dev/tty1 \
			--property=StandardInput=file:/dev/tty1 \
			--property=StandardOutput=file:/dev/tty1 \
			--property=StandardError=file:/dev/tty1 \
			--property=Type=forking \
			--property=WorkingDirectory=/home/radxa/ruby \
			/home/radxa/ruby/ruby_start
	else
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

		# start stream service
		echo "start stream service"
		systemd-run --unit=stream /gs/stream.sh

		# start button service
		echo "start button service"
		systemd-run --unit=button /gs/button.sh

		# start alink service
		[ "$alink_enable" == "yes" ] && systemd-run --unit=alink /usr/local/bin/alink --config /etc/alink.conf

		# copy video stream to local
		[[ "$wfb_outgoing_ip" != "224.0.0.1" && "$wfb_outgoing_ip" != "127.0.0.1" ]] && \
			iptables -t mangle -A OUTPUT -d $wfb_outgoing_ip -p udp --dport $wfb_outgoing_port_video -j TEE --gateway ${br0_fixed_ip%/*}

		# start wfb rtsp service
		[ "$wfb_rtsp_server_enable" == "yes" ] && systemctl start rtsp@$video_codec
	fi
fi

# start webui
[ "$webui_enable" == "yes" ] && systemctl start webui

# system boot complete, turn red record LED off
gpioset -D $red_led_drive $(gpiofind PIN_${red_led_pin})=0
echo "gs service start completed"

exit 0
