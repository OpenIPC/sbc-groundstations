#!/bin/bash

source /config/gs.conf

RUNNING=0
STREAMING=0

cd $REC_Dir


export DISPLAY=:0

video_play_cmd=""
video_rec_cmd=""

gencmd(){
	if [ $video_player == "fpvue" ]; then
		if [ $osd_enable == "yes" ];then
			video_rec_cmd="fpvue --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="fpvue --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE"
		else
			video_rec_cmd="fpvue --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="fpvue --screen-mode $SCREEN_MODE"
		fi
	elif [$video_player == "pixelpilot" ]; then
		if [ $osd_enable == "yes" ];then
			video_rec_cmd="pixelpilot --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="pixelpilot --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE"
		else
			video_rec_cmd="pixelpilot --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="pixelpilot --screen-mode $SCREEN_MODE"
		fi
	elif [$video_player == "gstreamer" ]; then
		video_play_cmd="gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H265' ! rtph265depay ! h265parse ! mppvideodec ! videoconvert ! rkximagesink plane-id=76"
		video_rec_cmd=" gst-launch-1.0 -e udpsrc port=5600 caps='application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H265' ! rtph265depay ! h265parse ! tee name=t ! mppvideodec ! rkximagesink plane-id=76 t. ! queue ! mpegtsmux ! filesink location=$1"
	else
		# use fpvue as default
		if [ $osd_enable == "yes" ];then
			video_rec_cmd="fpvue --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="fpvue --osd --osd-elements $osd_elements --osd-telem-lvl $osd_telem_lvl --screen-mode $SCREEN_MODE"
		else
			video_rec_cmd="fpvue --screen-mode $SCREEN_MODE --dvr $1"
			video_play_cmd="fpvue --screen-mode $SCREEN_MODE"
		fi

	fi
}

while true; do
	if [ $(gpioget $rec_gpio_chip $rec_gpio_offset) -eq 0 ]; then

		if [ $RUNNING -eq 0 ]; then
			kill -15 $STREAMING
			sleep 0.1
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
			RUNNING=$!
		else
			kill -15 $RUNNING
			RUNNING=0
			STREAMING=0
		fi
		sleep 0.1
	elif [ $STREAMING -eq 0 ]; then
		gencmd norecord
		$video_play_cmd &
		STREAMING=$!

	fi
	sleep 0.2
done
