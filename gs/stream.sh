#!/bin/bash

set -e
set -x

source /etc/gs.conf
export DISPLAY=:0
cd $rec_dir

video_record="0"
video_play_cmd=""
video_rec_cmd=""
case "$screen_mode" in
	"max-fps")
		screen_mode=$(pixelpilot --screen-mode-list | sort -t @ -k 2,2nr -k 1,1nr | head -n 1)
		echo "use max-fps screen_mode: $screen_mode"
		;;
	"max-res")
		screen_mode=$(pixelpilot --screen-mode-list | sort -t @ -k 1,1nr -k 2,2nr | head -n 1)
		echo "use max-resolution screen_mode: $screen_mode"
		;;
	*"x"*"@"*)
		screen_mode=${screen_mode%D}
		echo "use screen_mode in gs.conf: $screen_mode"
		;;
	*)
		echo "auto screen_mode"
		screen_mode=""
		;;
esac
[ -n "$screen_mode" ] && screen_mode_cmdline="--screen-mode $screen_mode"

# Auto select osd config file based on osd_type if osd_config_file is not set
if [ -z "$osd_config_file" ]; then
	case "$osd_type" in
		"msposd_air")
			osd_config_file="/etc/pixelpilot/pixelpilot_osd_simple.json"
			;;
		"msposd_gs")
			osd_config_file="/etc/pixelpilot/pixelpilot_msposd.json"
			;;
		*)
			osd_config_file="/etc/pixelpilot/pixelpilot_osd.json"
			;;
	esac
fi

GPIO_RED_LED=$(gpiofind PIN_${red_led_pin})

function gencmd(){
	if [ "$video_player" == "pixelpilot" ]; then
		video_play_cmd="pixelpilot $screen_mode_cmdline --codec $video_codec --dvr-framerate $rec_fps --dvr-fmp4 --dvr-template ${rec_dir}/record_%Y-%m-%d_%H-%M-%S.mp4 --dvr-sequenced-files"
		[ "$osd_enable" == "no" ] || video_play_cmd="$video_play_cmd --osd --osd-config $osd_config_file --osd-custom-message --osd-refresh $((1000 / ${osd_fps}))"
		[ "$record_on" == "arm" ] && video_play_cmd="$video_play_cmd --mavlink-dvr-on-arm"
		[ "$disable_vsync" == "yes" ] && video_play_cmd="$video_play_cmd --disable-vsync"
		video_rec_cmd="$video_play_cmd --dvr-start"
	elif [ "$video_player" == "gstreamer" ]; then
		# current_date=$(date +'%m-%d-%Y_%H-%M-%S')
		# gencmd record_${current_date}.ts
		rec_index=$(ls -1 $rec_dir | grep -oP "^\d+(?=\.mkv)" | tail -n 1)
		if [ -z $rec_index ]; then
			rec_index="1000"
		else
			rec_index=$(($rec_index + 1))
		fi
		video_play_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! mppvideodec ! kmssink"
		video_rec_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! tee name=t ! mppvideodec ! kmssink t. ! queue ! matroskamux ! filesink location=${rec_index}"
	else
		echo "wrong video player, only support pixelpilot and gstreamer"
	fi
}

function check_record_freespace() {
	local rec_dir_freespace=$(df $rec_dir | tail -n 1 | awk '{print $4}')
	local rec_dir_freespace_MB=$((${rec_dir_freespace} / 1024))
	if [ $rec_dir_freespace_MB -lt $rec_dir_freespace_min ]; then
		echo "insufficient"
	else
		echo "sufficient"
	fi
}

gencmd
# wait monitor connected
while true; do
	monitor_status=$(cat /sys/class/drm/card0-HDMI-A-1/status)
	[ "$monitor_status" == "connected" ] && break
	sleep 1
done
if [[ "$record_on" == "boot" && "$(check_record_freespace)" == "sufficient" ]]; then
	bash -c "$video_rec_cmd" &
	pid_player=$!
	video_record="1"
else
	bash -c "$video_play_cmd" &
	pid_player=$!
fi

# start OSD
(
if [ "$osd_enable" == "yes" ]; then
	if [[ "$video_player" == "pixelpilot" && "$osd_type" == "msposd_gs" ]]; then
		# start msposd_rockchip after /dev/shm/msposd is created and wfb tunnel is up
		while [[ ! -e /dev/shm/msposd || ! -d /sys/class/net/gs-wfb ]]; do sleep 1; done
		if [ "$msposd_gs_record" == "yes" ]; then
			msposd --master 0.0.0.0:$msposd_gs_port --osd -r $msposd_gs_fps --ahi $msposd_gs_ahi --subtitle $rec_dir
		else
			msposd --master 0.0.0.0:$msposd_gs_port --osd -r $msposd_gs_fps --ahi $msposd_gs_ahi
		fi
	elif [ "$video_player" == "gstreamer" ]; then
		wfb-ng-osd -p 14550
	fi
fi
) &

# show wallpaper
( sleep 10 && fbi -d /dev/fb0 -a -fitwidth -T 1 --noverbose /gs/wallpaper.png ) &

# Monitor button for start/stop reocrd
[ -p /run/record_button.fifo ] || mkfifo /run/record_button.fifo
while read record_button_action < /run/record_button.fifo; do
	[ "$record_button_action" == "single" ] || continue
	if [ "$video_record" == "0" ]; then
		if [ "$(check_record_freespace)" == "insufficient" ]; then
			echo "No enough record space!" > /run/pixelpilot.msg
			continue
		fi
		if [ "$video_player" == "pixelpilot" ]; then
			kill -SIGUSR1 $pid_player
		else
			kill -15 $pid_player
			sleep 0.2
			gencmd
			bash -c "$video_rec_cmd" &
			pid_player=$!
		fi
		echo "record start!" > /run/pixelpilot.msg
		video_record='1'
		(
		while true; do
			# Blink red record LED
			gpioset -D $red_led_drive -m time -s 1 ${GPIO_RED_LED}=1
			gpioset -D $red_led_drive -m time -s 1 ${GPIO_RED_LED}=0
		done
		) &
		pid_led=$!
	else
		# turn off record LED
		[ -z $pid_led ] || kill $pid_led
		sleep 1.2 && gpioset -D $red_led_drive ${GPIO_RED_LED}=0 &
		if [ "$video_player" == "pixelpilot" ]; then
			kill -SIGUSR1 $pid_player
		else
			kill -15 $pid_player
			sleep 0.2
			bash -c "$video_play_cmd" &
			pid_player=$!
		fi
		sync
		echo "record stop!" > /run/pixelpilot.msg
		video_record='0'
	fi
	sleep 3
done
