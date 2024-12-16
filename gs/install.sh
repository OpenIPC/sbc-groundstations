#!/bin/bash

set -ex
echo -e "\033[31mStart install gs\033[0m"

install_dir='/home/radxa/gs'
script_dir=$(dirname $(readlink -f $0))
cd $script_dir

if [ "$(id -u)" -ne 0 ]; then
  echo -e "This script must be run as root.\033[0m"
  exit 1
fi
[ -d ${install_dir} ] || mkdir -p ${install_dir}
[ "$(ls -A /etc/NetworkManager/system-connections/)" ] && rm /etc/NetworkManager/system-connections/*
systemctl disable wifibroadcast.service wifibroadcast@gs.service
chmod +x gs.sh wfb.sh stream.sh fan.sh button.sh button-kbd.py gs-init.sh channel-scan.sh
cp gs.sh wfb.sh stream.sh fan.sh button.sh button-kbd.py gs-applyconf.sh gs-init.sh channel-scan.sh rk3566-dwc3-otg-role-switch.dts rk3566-hdmi-max-resolution-4k.dts ${install_dir}/
cp gs.conf custom-sample.conf pixelpilot_osd.json pixelpilot_osd_simple.json /config/
cp gs.service gs-init.service /etc/systemd/system/
cp 99-wfb.rules 98-gadget.rules 99-kbd.rules /etc/udev/rules.d/
cp ../pics/OpenIPC.png ${install_dir}/wallpaper.png
systemctl enable gs-init.service
systemctl enable gs.service
cp FPVue.key /config/gs.key
[ $(readlink -f /etc/gs.key) == "/config/gs.key" ] || ( [ -f /etc/gs.key ] && rm /etc/gs.key; ln -s /config/gs.key /etc/gs.key )
[ $(readlink -f /etc/gs.conf) == "/config/gs.conf" ] || ( [ -f /etc/gs.conf ] &&  rm /etc/gs.conf; ln -s /config/gs.conf /etc/gs.conf )

echo -e "\033[31mInstallation Complete, Configuration file is /config/gs.conf\033[0m"
sync
echo -e "\033[31mRestart required to take effect!\033[0m"
