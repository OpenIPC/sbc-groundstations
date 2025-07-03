#!/bin/bash

set -e
source /etc/gs.conf

# Exit if gs service is not enable
[ -e /etc/systemd/system/multi-user.target.wants/gs.service ] || exit 0
# Exit if gs is not enable
[ "$gs_enable" == 'no' ] && exit 0
# Passing record button state from button.sh to stream.sh
[ -p /run/record_button.fifo ] || mkfifo /run/record_button.fifo

# change wifi mode between station and hotspot
function change_wifi_mode() {
	if [ ! -d /sys/class/net/wifi0 ]; then
		echo "WARING: no wifi0 found, can't switch wifi mode."
		exit 0
	elif [ "$wfb_integrated_wnic" == "wifi0" ]; then
		echo "WARING: wifi0 used by wfb, can't switch wifi mode."
		exit 0
	fi
	wifi0_connected_connection=$(nmcli device status | grep '^wifi0.*connected' | tr -s ' ' | cut -d ' ' -f 4)
	case "$wifi0_connected_connection" in
		"hotspot")
			echo "Prepare connect to ${wifi_ssid}!" > /run/pixelpilot.msg
			if nmcli connection up wifi0 > /dev/null 2>&1; then
				echo "WiFi connected to ${wifi_ssid}!" > /run/pixelpilot.msg
			else
				nmcli connection up hotspot
				echo "Failed connect to ${wifi_ssid}, fallback to hotspot mode!" > /run/pixelpilot.msg
			fi
			sleep 3
			;;
		"wifi0"|"--")
			echo "Prepare change to hotspot mode!" > /run/pixelpilot.msg
			if nmcli connection up hotspot > /dev/null 2>&1; then
				echo "WiFi changed to hotspot mode!" > /run/pixelpilot.msg
			else
				echo "Failed change to hotspot mode!" > /run/pixelpilot.msg
			fi
			sleep 3
			;;
		*)
			echo "connection is unknow"
			;;
	esac
}

# change usb otg mode between host and device
function change_otg_mode() {
	local otg_mode_LED_PIN_info=$(gpiofind PIN_${!otg_mode_led_pin})
	local otg_mode_file="/sys/kernel/debug/usb/fcc00000.dwc3/mode"
	local otg_mode=$(cat $otg_mode_file)
	if [ "$otg_mode" == "host" ]; then
		echo device > $otg_mode_file
		echo "change otg mode to device!" > /run/pixelpilot.msg
		sleep 0.2
		if [ -d /sys/kernel/config/usb_gadget/g1 ]; then
			ls /sys/class/udc > /sys/kernel/config/usb_gadget/g1/UDC
		else
			/gs/otg-gadget.sh &
		fi
		# [ "$(ip link ls radxa0 | grep -oP '(?<=state ).+(?=mode)')" == "DOWN"  ] && ifup radxa0
		(
		while true; do
			# Blink green power LED
			gpioset -D ${!otg_mode_led_drive} -m time -s 1 $otg_mode_LED_PIN_info=1
			gpioset -D ${!otg_mode_led_drive} -m time -s 1 $otg_mode_LED_PIN_info=0
		done
		) &
		local pid_led=$!
	elif [ "$otg_mode" == "device" ]; then
		echo host > $otg_mode_file
		echo "change otg mode to host!" > /run/pixelpilot.msg
		[ -z "$pid_led" ] || kill $pid_led
		sleep 1.2
		gpioset -D ${!otg_mode_led_drive} -m time -s 1 $otg_mode_LED_PIN_info=1
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

# start or stop stream
function toggle_stream() {
	if [ -h "/run/systemd/units/invocation:stream.service" ]; then
		echo "Stop stream service" > /run/pixelpilot.msg
		sleep 1
		systemctl stop stream.service
	else
		systemd-run --unit=stream /gs/stream.sh
	fi
}

# cleanup record files
function cleanup_record_files() {
	# first long press cleanup record files until have enough space
	# secord long press in 60s will remove all record files
	record_file_list=$(find $rec_dir -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' \))
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
	echo "apply gs.conf!" > /run/pixelpilot.msg
	/gs/gs-applyconf.sh
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

# mount extdisk first partition to rec_dir
function mount_extdisk() {
	local root_dev=$(findmnt -n -o SOURCE /)
	# skip if boot from MicroSD
	[[ "$root_dev" == "/dev/mmcblk1p"? && "${arg_2}" == "/dev/mmcblk1p1" ]] && exit 0
	# mount in root mnt namespace. Udev mount will use systemd-udevd mnt namespace by default.
	if nsenter --mount=/proc/1/ns/mnt mount ${arg_2} ${rec_dir} > /dev/null 2>&1; then
		partitioninfo=$(df -hT ${rec_dir} | tail -n 1 | tr -s ' ')
		echo "$partitioninfo" > /run/pixelpilot.msg
	else
		echo "mount extdisk failed, check fstype and file system" > /run/pixelpilot.msg
	fi
}

# unmount extdisk video partition
function ummount_extdisk() {
	if grep -Eq "^/dev/sda1 /${rec_dir}|^/dev/mmcblk1p1 /${rec_dir}" /proc/mounts; then
		if umount -lf "$rec_dir" > /dev/null 2>&1; then
			echo "umount $rec_dir success" > /run/pixelpilot.msg
		else
			echo "umount $rec_dir failed, check record status" > /run/pixelpilot.msg
		fi
	else
		echo "extdisk already umounted" > /run/pixelpilot.msg
	fi
}

# Add more custom functions above

# Pass function name to script to execute the function
if [ -n "$1" ] && declare -f $1 > /dev/null; then
	[ -n "$2" ] && arg_2=$2
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
	local gpio_pin="${1}_pin"
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

# up/down/left/right/q1 is used by PixelPilot_rk
if [ "$video_player" != "pixelpilot" ]; then
	execute_button_function btn_cu &
	execute_button_function btn_cd &
	execute_button_function btn_cl &
	execute_button_function btn_cr &
	execute_button_function btn_cm &
	execute_button_function btn_q1 &
fi
execute_button_function btn_q2 &
execute_button_function btn_q3 &

wait
