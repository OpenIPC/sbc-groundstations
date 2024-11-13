#!/bin/bash

set -e
set -x

source /config/gs.conf
export DISPLAY=:0
cd $REC_Dir

video_record="0"
video_play_cmd=""
video_rec_cmd=""
[ -n "$screen_mode" ] && screen_mode="--screen-mode $screen_mode"
[ -n "$REC_GPIO_PIN" ] && GPIO_REC=$(gpiofind PIN_${REC_GPIO_PIN})
GPIO_REC_LED=$(gpiofind PIN_${REC_LED_PIN})

function gencmd(){
	if [ "$video_player" == "pixelpilot" ]; then
		video_play_cmd="pixelpilot $screen_mode --codec $video_codec --dvr-framerate $REC_FPS --dvr-fmp4 --dvr-template ${REC_Dir}/record_%Y-%m-%d_%H-%M-%S.mp4"
		[ "$osd_enable" == "no" ] || video_play_cmd="$video_play_cmd --osd --osd-elements '' --osd-config $osd_config_file --osd-custom-message"
	elif [ "$video_player" == "gstreamer" ]; then
		video_play_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! mppvideodec ! kmssink"
		video_rec_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! tee name=t ! mppvideodec ! kmssink t. ! queue ! matroskamux ! filesink location=${1}"
	else
		echo "wrong video player, only support pixelpilot and gstreamer"
	fi
}

gencmd norecord
bash -c "$video_play_cmd" &
pid_player=$!
while gpiomon -r -s -n 1 -B pull-down ${GPIO_REC}; do
	# do a 50ms simple software de-bounce
	sleep 0.05
	[ "$(gpioget $GPIO_REC)" == "1" ] || continue
	if [ "$video_record" == "0" ]; then
		rec_dir_freespace=$(df $REC_Dir | grep $REC_Dir | awk '{print $4}')
		rec_dir_freespace_MB=$((${rec_dir_freespace} / 1024))
		if [ $rec_dir_freespace_MB -lt $rec_dir_freespace_min ]; then
			echo "No enough record space!" > /run/pixelpilot.msg
			continue
		fi
		if [ "$video_player" == "pixelpilot" ]; then
			kill -SIGUSR1 $pid_player
		else
			kill -15 $pid_player
			sleep 0.2
			# current_date=$(date +'%m-%d-%Y_%H-%M-%S')
			# gencmd record_${current_date}.ts
			rec_index=$(ls -1 $REC_Dir | grep -oP "^\d+(?=\.mkv)" | tail -n 1)
			if [ -z $rec_index ]; then
				rec_index="1000"
			else
				rec_index=$(($rec_index + 1))
			fi
			gencmd ${rec_index}.mkv
			bash -c "$video_rec_cmd" &
			pid_player=$!
		fi
		video_record='1'
		# Todo: How to deal with led when system is overheat
		(
		while true; do
			# Blink red record LED
			gpioset -D $REC_LED_drive -m time -s 1 ${GPIO_REC_LED}=1
			gpioset -D $REC_LED_drive -m time -s 1 ${GPIO_REC_LED}=0
		done
		) &
		pid_led=$!
	else
		# turn off record LED
		[ -z $pid_led ] || kill $pid_led
		sleep 1.2 && gpioset -D $REC_LED_drive ${GPIO_REC_LED}=0 &
		if [ "$video_player" == "pixelpilot" ]; then
			kill -SIGUSR1 $pid_player
		else
			kill -15 $pid_player
			sleep 0.2
			gencmd norecord
			bash -c "$video_play_cmd" &
			pid_player=$!
		fi
		video_record='0'
	fi
	sleep 3
done
