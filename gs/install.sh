#!/bin/bash

set -e

install_dir='/home/radxa/gs'
script_dir=$(dirname $(readlink -f $0))
cd $script_dir

if [ "$(id -u)" -ne 0 ]; then
  echo -e "This script must be run as root.\033[0m"
  exit 1
fi

[ -d ${install_dir}/udev-rules-bak ] || mkdir -p ${install_dir}/udev-rules-bak

echo -e "\033[31mRemove /etc/NetworkManager/system-connections/*\033[0m"
[ "$(ls -A /etc/NetworkManager/system-connections/)" ] && rm /etc/NetworkManager/system-connections/*
echo -e "\033[31mDisable wifibroadcast.service wifibroadcast@gs.service\033[0m"
systemctl disable wifibroadcast.service wifibroadcast@gs.service
echo -e "\033[31mcopy gs.sh wfb.sh stream.sh fan.sh button.sh init.sh rk3566-dwc3-otg-role-switch.dts rk3566-hdmi-max-resolution-4k.dts to ${install_dir}/\033[0m"
chmod +x gs.sh wfb.sh stream.sh fan.sh button.sh init.sh && cp gs.sh wfb.sh stream.sh fan.sh button.sh init.sh rk3566-dwc3-otg-role-switch.dts rk3566-hdmi-max-resolution-4k.dts ${install_dir}/
echo -e "\033[31mcopy gs.conf to /config/gs.conf\033[0m"
cp gs.conf /config/
echo -e "\033[31mcopy gs.service to /etc/systemd/system/\033[0m"
cp gs.service /etc/systemd/system/
echo -e "\033[31mBackup exist udev rules to ${install_dir}/udev-rules-bak/\033[0m"
[ -f /etc/udev/rules.d/98-custom-wifi.rules ] && mv /etc/udev/rules.d/98-custom-wifi.rules ${install_dir}/udev-rules-bak/
[ -f /etc/udev/rules.d/99-custom-wifi.rules ] && mv /etc/udev/rules.d/99-custom-wifi.rules ${install_dir}/udev-rules-bak/
echo -e "\033[31mcopy 99-wfb.rules 98-gadget.rules to /etc/udev/rules.d/\033[0m"
cp 99-wfb.rules 98-gadget.rules /etc/udev/rules.d/
echo "cpoy ../pics/OpenIPC.png ${install_dir}/wallpaper.png"
cp ../pics/OpenIPC.png ${install_dir}/wallpaper.png
echo -e "\033[31msystemctl enable gs.service \033[0m"
systemctl daemon-reload
systemctl enable gs
echo -e "\033[31mCopy FPVue.key to /config/gs.key and linked to /etc/gs.key\033[0m"
cp FPVue.key /config/gs.key
[ $(readlink -f /etc/gs.key) == "/config/gs.key" ] || ( [ -f /etc/gs.key ] && rm /etc/gs.key; ln -s /config/gs.key /etc/gs.key )
echo -e "\033[31mLinked /config/gs.conf to /etc/gs.conf\033[0m"
[ $(readlink -f /etc/gs.conf) == "/config/gs.conf" ] || ( [ -f /etc/gs.conf ] &&  rm /etc/gs.conf; ln -s /config/gs.conf /etc/gs.conf )

echo -e "\033[31mInstallation Complete, Configuration file is /config/gs.conf\033[0m"
sync
echo -e "\033[31mRestart required to take effect!\033[0m"



