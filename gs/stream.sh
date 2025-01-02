#!/bin/bash

set -e
set -x

source /config/gs.conf
export DISPLAY=:0
cd $REC_Dir

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
		echo "use screen_mode in gs.conf: $screen_mode"
		;;
	*)
		echo "auto screen_mode"
		screen_mode=""
		;;
esac
[ -n "$screen_mode" ] && screen_mode_cmdline="--screen-mode $screen_mode"

[ -n "$BTN_Q1_PIN" ] && GPIO_REC=$(gpiofind PIN_${BTN_Q1_PIN})
GPIO_RED_LED=$(gpiofind PIN_${RED_LED_PIN})

function gencmd(){
	if [ "$video_player" == "pixelpilot" ]; then
		video_play_cmd="pixelpilot $screen_mode_cmdline --codec $video_codec --dvr-framerate $REC_FPS --dvr-fmp4 --dvr-template ${REC_Dir}/record_%Y-%m-%d_%H-%M-%S.mp4"
		[ "$osd_enable" == "no" ] || video_play_cmd="$video_play_cmd --osd --osd-elements '' --osd-config $osd_config_file --osd-custom-message"
		[ "$record_on" == "arm" ] && video_play_cmd="$video_play_cmd --mavlink-dvr-on-arm"
		video_rec_cmd="$video_play_cmd --dvr-start"
	elif [ "$video_player" == "gstreamer" ]; then
		# current_date=$(date +'%m-%d-%Y_%H-%M-%S')
		# gencmd record_${current_date}.ts
		rec_index=$(ls -1 $REC_Dir | grep -oP "^\d+(?=\.mkv)" | tail -n 1)
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
	local rec_dir_freespace=$(df $REC_Dir | tail -n 1 | awk '{print $4}')
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
# show wallpaper
( sleep 10 && fbi -d /dev/fb0 -a -fitwidth -T 1 --noverbose /gs/wallpaper.png ) &
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
			gpioset -D $RED_LED_drive -m time -s 1 ${GPIO_RED_LED}=1
			gpioset -D $RED_LED_drive -m time -s 1 ${GPIO_RED_LED}=0
		done
		) &
		pid_led=$!
	else
		# turn off record LED
		[ -z $pid_led ] || kill $pid_led
		sleep 1.2 && gpioset -D $RED_LED_drive ${GPIO_RED_LED}=0 &
		if [ "$video_player" == "pixelpilot" ]; then
			kill -SIGUSR1 $pid_player
		else
			kill -15 $pid_player
			sleep 0.2
			bash -c "$video_play_cmd" &
			pid_player=$!
		fi
		echo "record stop!" > /run/pixelpilot.msg
		video_record='0'
	fi
	sleep 3
done
