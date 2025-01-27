#!/bin/bash

source /etc/gs.conf

pwmchip_path="/sys/class/pwm/pwmchip${fan_pwm_chip}"
if [ ! -d $pwmchip_path ]; then
	echo "Need enale pwmchip${fan_pwm_chip} channel $fan_pwm_channel in rsetup!"
elif [ ! -d ${pwmchip_path}/pwm${fan_pwm_channel} ]; then
	echo "export channel $fan_pwm_channel to pwmchip${fan_pwm_chip}"
	echo $fan_pwm_channel > ${pwmchip_path}/export
	echo "Using pwmchip${fan_pwm_chip} channel $fan_pwm_channel for fan"
else
	echo "Using pwmchip${fan_pwm_chip} channel $fan_pwm_channel for fan"
fi

cd ${pwmchip_path}/pwm${fan_pwm_channel}
period=$((1000000000 / $fan_pwm_frequency))
one_percent_period=$(($period / 100))
echo $period > period
echo $(($period / 5)) > duty_cycle
echo 1 > enable
# if direct connect pwm pin to fan, need set polarity to normal
echo $fan_pwm_polarity > polarity
sleep 10

while true; do
	temp_cpu=$(cat /sys/class/thermal/thermal_zone0/temp)
	temp_max=${temp_cpu:0:-3}
	echo "CPU temperature: ${temp_max}°"
	if [[ "$monitor_8812eu_temperature" == "yes" && -d /proc/net/rtl88x2eu && $(ls /proc/net/rtl88x2eu | wc -l) -gt 10 ]]; then
		for temp_file in /proc/net/rtl88x2eu/*/thermal_state; do
			temp_eu_info=$(head -n 1 $temp_file)
			temp_eu=$((${temp_eu_info##* } + ${rtl8812eu_temperature_offset}))
			echo "RTL8812EU  temp: ${temp_eu}°"
			[ $temp_eu -gt $temp_max ] && temp_max=$temp_eu
		done
	fi
	echo "Max temperature: ${temp_max}°"
	target_temp_min=$(($fan_target_temperature - $fan_target_temperature_deviation))	
	target_temp_max=$(($fan_target_temperature + $fan_target_temperature_deviation))	
	duty_cycle_now=$(cat ${pwmchip_path}/pwm${fan_pwm_channel}/duty_cycle)

	if [ $temp_max -gt $fan_overheat_temperature ];then
		echo "CATION: System is overheat! fan speed up to 100%!"
		echo $period > ${pwmchip_path}/pwm${fan_pwm_channel}/duty_cycle
		echo "System overheat!" > /run/pixelpilot.msg
	elif [ $temp_max -gt $target_temp_max ]; then
		if [ $duty_cycle_now -lt $(($fan_pwm_max_duty_cycle * $one_percent_period)) ]; then
			echo "$temp_max is greater than ${target_temp_max}, fan speed up ${fan_pwm_step_duty_cycle}%"
			echo $(($duty_cycle_now + $fan_pwm_step_duty_cycle * $one_percent_period)) > ${pwmchip_path}/pwm${fan_pwm_channel}/duty_cycle
		else
			echo "$temp_max is greater than ${target_temp_max}, but max fan speed limited to ${fan_pwm_max_duty_cycle}%"
		fi
	elif [ $temp_max -lt $target_temp_min ]; then
		if [ $duty_cycle_now -gt $(($fan_pwm_min_duty_cycle * $one_percent_period)) ];then
			echo "$temp_max is less than ${target_temp_min}, fan speed down ${fan_pwm_step_duty_cycle}%"
			echo $(($duty_cycle_now - $fan_pwm_step_duty_cycle * $one_percent_period)) > ${pwmchip_path}/pwm${fan_pwm_channel}/duty_cycle
		else
			echo "$temp_max is less than ${target_temp_min}, but min fan speed limited to ${fan_pwm_min_duty_cycle}%"
		fi
	else
		echo "$temp_max is between $target_temp_min and ${target_temp_max}, Keep speed"
	fi
	echo "----------------------${date}--------------------"
	sleep $temperature_monitor_cycle
done
