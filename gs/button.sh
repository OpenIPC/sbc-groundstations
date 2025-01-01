#!/bin/bash

set -e
source /config/gs.conf

# change wifi mode between station and hotspot
function change_wifi_mode() {
	if [ ! -d /sys/class/net/wifi0 ]; then
		echo "WARING: no wifi0 found, can't switch wifi mode."
		exit 0
	elif [ "$wfb_integrated_wnic" == "wifi0" ]; then
		echo "WARING: wifi0 used by wfb, can't switch wifi mode."
		exit 0
	else
		wifi0_connected_connection=$(nmcli device status | grep '^wifi0.*connected' | tr -s ' ' | cut -d ' ' -f 4)
		case "$wifi0_connected_connection" in
			hotspot)
				nmcli connection up wifi0
				sleep 5
				;;
			wifi0)
				nmcli connection up hotspot
				sleep 5
				;;
			*)  echo "connection is unknow"
				;;
		esac
	fi
}

# change usb otg mode between host and device
function change_otg_mode() {
	local otg_mode_LED_PIN_info=$(gpiofind PIN_${otg_mode_LED_PIN})
	local otg_mode_file="/sys/kernel/debug/usb/fcc00000.dwc3/mode"
	local otg_mode=$(cat $otg_mode_file)
	if [ "$otg_mode" == "host" ]; then
		echo device > $otg_mode_file
		sleep 0.2
		[ -d /sys/kernel/config/usb_gadget/fcc00000.dwc3/functions/ffs.adb ] || systemctl start radxa-adbd@fcc00000.dwc3.service
		[ -f /sys/class/net/radxa0 ] || systemctl start radxa-ncm@fcc00000.dwc3.service
		sleep 1
		# [ "$(ip link ls radxa0 | grep -oP '(?<=state ).+(?=mode)')" == "DOWN"  ] && ifup radxa0
		(
		while true; do
			# Blink green power LED
			gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=1
			gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=0
		done
		) &
		local pid_led=$!
	elif [ "$otg_mode" == "device" ]; then
		echo host > $otg_mode_file
		[ -z "$pid_led" ] || kill $pid_led
		sleep 1.2
		gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=1
	else
		echo "otg mode is unkonw"
	fi

}

# scan wfb wifi channel
function scan_wfb_channel() {
	/gs/channel-scan.sh
}

# start or stop recording
function toggle_record() {
	echo "single" > /run/record_button.fifo
}

# cleanup record files
function cleanup_record_files() {
	# first long press cleanup record files until have enough space
	# secord long press in 60s will remove all record files
	record_file_list=$(find $REC_Dir -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' \))
	if [ -n "$record_file_list" ];then
		if [ ! -f /tmp/cleanup_record ]; then
			for record_file in $record_file_list; do
				[ "$(check_record_freespace)" == "sufficient" ] && break
				rm $record_file
			done
			echo "cleanup record done!" > /run/pixelpilot.msg
			(
			touch /tmp/cleanup_record
			sleep 60
			[ -f /tmp/cleanup_record ] && rm /tmp/cleanup_record
			) &
		else
			for record_file in $record_file_list; do
				rm $record_file
			done
			[ -f /tmp/cleanup_record ] && rm /tmp/cleanup_record
			echo "All record file deleted!" > /run/pixelpilot.msg
		fi
	else
		echo "no record file found!" > /run/pixelpilot.msg
	fi
}

# check and apply configuration in gs.conf
function apply_conf() {
	(
	source /config/gs.conf
	source /gs/gs-applyconf.sh
	) &
}

# shutdown Ground Station
function shutdown_gs() {
	echo "Ground Station going to shutdown in 2 seconds!" > /run/pixelpilot.msg
	( sleep 2 && poweroff) &
}

# reboot Ground Station
function reboot_gs() {
	echo "Ground Station going to reboot in 2 seconds!" > /run/pixelpilot.msg
	( sleep 2 && reboot) &
}

# Add more custom functions above

# Pass function name to script to execute the function
if [ -n "$1" ] && declare -f $1 > /dev/null; then
	$1
	exit 0
else
	echo "function $1 not found"
fi

function button_action() {
	local gpio_info=$(gpiofind PIN_${1})
	while gpiomon -r -s -n 1 -B pull-down ${gpio_info}; do
		sleep 0.05
		[ "$(gpioget ${gpio_info})" == "1" ] || continue
		local button_press_uptime=$(cut -d ' ' -f 1 /proc/uptime | tr -d .)
		gpiomon -f -s -n 1 -B pull-down ${gpio_info}
		local button_release_uptime=$(cut -d ' ' -f 1 /proc/uptime | tr -d .)
		local button_pressed_time=$((${button_release_uptime} - ${button_press_uptime}))
		if [ $button_pressed_time -lt 200 ]; then
			echo "single"
		elif [ $button_pressed_time -ge 200 ]; then
			echo "long"
		fi
		break
	done
}

function execute_button_function() {
	local gpio_pin="${1}_PIN"
	[ -z "${!gpio_pin}" ] && exit 0
	local single_press_function="${1}_single_press"
	local long_press_function="${1}_long_press"
	[ -z "${!single_press_function}" ] && [ -z "${!long_press_function}" ] && exit 0
	while true; do
		local action=$(button_action ${!gpio_pin})
		case $action in
			single)
				${!single_press_function}
				;;
			long)
				${!long_press_function}
				;;
			*)
				echo "unknow button action"
		esac

	done
}

execute_button_function BTN_Q1 &
execute_button_function BTN_Q2 &
execute_button_function BTN_Q3 &
execute_button_function BTN_CU &
execute_button_function BTN_CD &
execute_button_function BTN_CL &
execute_button_function BTN_CR &
execute_button_function BTN_CM &

wait
