#!/bin/bash

source /config/gs.conf

(
otg_mode_switch_PIN_info=$(gpiofind PIN_${otg_mode_switch_PIN})
otg_mode_file="/sys/kernel/debug/usb/fcc00000.dwc3/mode"
while true; do
        if [ "$(gpiomon -F %e -n 1 $(otg_mode_switch_PIN_info))" == "1" ]; then
		otg_mode=$(cat $otg_mode_file)
                if [ "$otg_mode" == "host" ]; then
			echo device > $otg_mode_file
			sleep 0.2
			systemctl restart radxa-adbd@fcc00000.dwc3.service radxa-ncm@fcc00000.dwc3.service
			(
			while true; do
				# Blink green power LED
				gpioset -D $PWR_LED_drive -m time -s 1 $otg_mode_switch_PIN_info=1
				gpioset -D $PWR_LED_drive -m time -s 1 $otg_mode_switch_PIN_info=0
			done
			) &
			pid_led=$!
		elif [ "$otg_mode" == "device" ]; then
			echo host > $otg_mode_file
			[ -z $pid_led ] || kill $pid_led
			sleep 1.2
			gpioset -D $PWR_LED_drive -m time -s 1 $otg_mode_switch_PIN_info=1
		fi
	fi
done


) &
