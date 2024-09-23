#!/bin/bash

install_dir='/home/radxa/gs'
script_dir=$(dirname $(readlink -f $0))
cd $script_dir

echo "Delete gs.service and enable wifibroadcast service"
systemctl disable gs
rm /etc/systemd/system/gs.service
systemctl daemon-reload
systemctl enable wifibroadcast.service wifibroadcast@gs.service

echo "Restore udev rules"
rm /etc/udev/rules.d/99-wfb.rules
mv ${install_dir}/udev-rules-bak/* /etc/udev/rules.d/

echo "Remove files"
rm /config/gs.conf
rm /etc/NetworkManager/system-connections/*
rm /etc/network/interfaces.d/wfb*
rm -rf /home/radxa/gs

echo "uninstall done, need reboot!"
