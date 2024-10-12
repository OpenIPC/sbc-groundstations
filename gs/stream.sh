#!/bin/bash

set -e

source /config/gs.conf
export DISPLAY=:0
cd $REC_Dir

video_record="0"
video_play_cmd=""
video_rec_cmd=""

function gencmd(){
	if [ "$video_player" == "pixelpilot" ]; then
		video_rec_cmd="pixelpilot --screen-mode $SCREEN_MODE --codec $video_codec --dvr-framerate $REC_FPS --dvr-fmp4 --dvr $1"
		video_play_cmd="pixelpilot --screen-mode $SCREEN_MODE --codec $video_codec"
		if [ "$osd_enable" == "yes" ];then
			video_rec_cmd="$video_rec_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
			video_play_cmd="$video_play_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
		fi
	elif [ "$video_player" == "gstreamer" ]; then
		video_play_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! mppvideodec ! kmssink"
		video_rec_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H${video_codec:1:4}' ! rtp${video_codec}depay ! ${video_codec}parse ! tee name=t ! mppvideodec ! kmssink t. ! queue ! mp4mux ! filesink location=${1}"
	else
		# use fpvue as default
		video_rec_cmd="fpvue --screen-mode $SCREEN_MODE --codec $video_codec --dvr $1"
		video_play_cmd="fpvue --screen-mode $SCREEN_MODE --codec $video_codec"
		if [ "$osd_enable" == "yes" ];then
			video_rec_cmd="$video_rec_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
			video_play_cmd="$video_play_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
		fi

	fi
}

gencmd norecord
bash -c "$video_play_cmd" &
pid_player=$!
while [ "$(gpiomon -F %e -n 1 $(gpiofind PIN_${REC_GPIO_PIN}))" == "1" ]; do
	if [ "$video_record" == "0" ]; then
		kill -15 $pid_player
		sleep 0.2
		# current_date=$(date +'%m-%d-%Y_%H-%M-%S')
		# gencmd record_${current_date}.ts
		rec_index=$(ls -1 $REC_Dir | grep -oP "^\d+(?=\.mp4)" | tail -n 1)
		if [ -z $rec_index ]; then
			rec_index="1000"
		else
			rec_index=$(($rec_index + 1))
		fi
		gencmd ${rec_index}.mp4
		bash -c "$video_rec_cmd" &
		pid_player=$!
		video_record='1'
		# Todo: How to deal with led when system is overheat
		(
		while true; do
			# Blink red record LED
			gpioset -D $REC_LED_drive -m time -s 1 $(gpiofind PIN_${REC_LED_PIN})=1
			gpioset -D $REC_LED_drive -m time -s 1 $(gpiofind PIN_${REC_LED_PIN})=0
		done
		) &
		pid_led=$!
	else
		kill -15 $pid_player
		[ -z $pid_led ] || kill $pid_led
		sleep 0.2
		sleep 1 && gpioset -D $REC_LED_drive $(gpiofind PIN_${REC_LED_PIN})=0 &
		gencmd norecord
		bash -c "$video_play_cmd" &
		pid_player=$!
		video_record='0'
	fi
	sleep 1
done
