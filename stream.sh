#!/bin/bash

source /config/gs.conf
export DISPLAY=:0
cd $REC_Dir

video_record="0"
video_play_cmd=""
video_rec_cmd=""

function gencmd(){
	if [$video_player == "pixelpilot" ]; then
		video_rec_cmd="pixelpilot --screen-mode $SCREEN_MODE --dvr $1"
		video_play_cmd="pixelpilot --screen-mode $SCREEN_MODE"
		if [ $osd_enable == "yes" ];then
			video_rec_cmd="$video_rec_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
			video_play_cmd="$video_play_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
		fi
	elif [$video_player == "gstreamer" ]; then
		video_play_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H265' ! rtph265depay ! h265parse ! mppvideodec ! videoconvert ! rkximagesink plane-id=76"
		video_rec_cmd=" gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H265' ! rtph265depay ! h265parse ! tee name=t ! mppvideodec ! rkximagesink plane-id=76 t. ! queue ! mpegtsmux ! filesink location=$1"
	else
		# use fpvue as default
		video_rec_cmd="fpvue --screen-mode $SCREEN_MODE --dvr $1"
		video_play_cmd="fpvue --screen-mode $SCREEN_MODE"
		if [ $osd_enable == "yes" ];then
			video_rec_cmd="$video_rec_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
			video_play_cmd="$video_play_cmd --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl"
		fi

	fi
}

gencmd norecord
$video_play_cmd &
pid_player=$!
while true; do
	if [ $(gpiomon -F %e -n 1 $(gpiofind PIN_${REC_GPIO_PIN})) == "1" ]; then
		if [ $video_record == "0" ]; then
			kill -15 $pid_player
			sleep 0.2
			# current_date=$(date +'%m-%d-%Y_%H-%M-%S')
			# gencmd record_${current_date}.ts
			lastfile=$(ls -1 | tail -n 1)
			rec_index=${lastfile%.*}
			if [[ $rec_index =~ ^-?[0-9]+$ ]]; then
				rec_index=$(($rec_index + 1))
			else
				rec_index=1000
			fi
			gencmd ${rec_index}.ts
			$video_rec_cmd &
			pid_player=$!
			video_record='1'
			# Todo: How to deal with led when system is overheat
			(
			while true; do
				# Blink red record LED
				gpioset -D $REC_LED_drive $(gpiofind PIN_${REC_GPIO_PIN})=1
				sleep 1
				gpioset -D $REC_LED_drive $(gpiofind PIN_${REC_GPIO_PIN})=0
			done
		        ) &
			pid_led=$!
		else
			kill -15 $pid_player
			kill $pid_led
			sleep 0.2
			gencmd norecord
			$video_play_cmd &
			pid_player=$!
			video_record='0'
		fi
	fi
	sleep 1
done
