#!/bin/bash

set -e
set -x
source /config/gs.conf

sleep 12
setfont /usr/share/consolefonts/CyrAsia-TerminusBold32x16.psf.gz
cat | tee /dev/ttyFIQ0 /dev/tty1 << EOF

############################### Welcome to SBC Ground Station ##################################
#                                                                                              #
# WARING: Thist is init startup, may take few minuts, system will auto restart when init done. #
# WARING: Do not turn off the power during the initialization process.                         #
#                                                                                              #
################################################################################################

EOF

BOARD=$(cat /etc/hostname)

# Create a partition(exfat) to save record videos
[ -d $REC_Dir ] || mkdir -p $REC_Dir
os_dev=$(blkid | grep rootfs | grep -oP "/dev/.+(?=p\d+)") || true
if [ ! -b ${os_dev}p4 ]; then
        sgdisk -ge $os_dev
        root_partirion_size=$(parted -s $os_dev p | grep -oP "\d+(?=MB\s*ext4)")
        root_partirion_size_new=$(( root_partirion_size + $rootfs_reserved_space ))
        cat << EOF | parted ---pretend-input-tty $os_dev > /dev/null 2>&1
resizepart 3 ${root_partirion_size_new}MiB
yes
EOF
        resize2fs ${os_dev}p3
        root_partirion_end=$(parted -s $os_dev p | grep rootfs | tr -s ' ' | cut -d ' ' -f 4)
        parted -s $os_dev mkpart videos fat32 ${root_partirion_end} 100%
        mkfs.exfat ${os_dev}p4
fi
# mount /dev/disk/by-partlabel/videos $REC_Dir
if [ "${REC_Dir}" != "$(grep -oP '(?<=^/dev/mmcblk1p4\t).*?(?=\t)' /etc/fstab)" ]; then
	echo -e "${os_dev}p4\t${REC_Dir}\texfat\tdefaults\t0\t0" >> /etc/fstab
fi

# Enable dtbo
# set max resolution to 4k
dtc -I dts -O dtb -o /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo /home/radxa/gs/rk3566-hdmi-max-resolution-4k.dts
# enbale USB OTG role switch
dtc -I dts -O dtb -o /boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo /home/radxa/gs/rk3566-dwc3-otg-role-switch.dts
dtbo_enable_array=($dtbo_enable_list)
for dtbo in "${dtbo_enable_array[@]}"; do
	mv /boot/dtbo/rk3568-${dtbo}.dtbo.disabled /boot/dtbo/rk3568-${dtbo}.dtbo
done
u-boot-update

# Add eth0 network configuration
[ -f /etc/systemd/network/eth0.network ] || cat > /etc/systemd/network/eth0.network << EOF
[Match]
Name=eth0

[Network]
Address=${eth0_fixed_ip}
Address=${eth0_fixed_ip2}
DHCP=yes
EOF

# Add br0 network configuration
[ -f /etc/systemd/network/br0.netdev ] || cat > /etc/systemd/network/br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge
EOF

[ -f /etc/systemd/network/br0.network ] || cat > /etc/systemd/network/br0.network << EOF
[Match]
Name=br0

[Network]
Address=${br0_fixed_ip}
DHCP=yes
EOF

[ -f /etc/systemd/network/usb0.network ] || cat > /etc/systemd/network/usb0.network << EOF
[Match]
Name=usb0

[Network]
Bridge=br0
EOF

[ -f /etc/systemd/network/dummy0.netdev ] || cat > /etc/systemd/network/dummy0.netdev << EOF
[NetDev]
Name=dummy0
Kind=dummy
EOF

[ -f /etc/systemd/network/dummy0.network ] || cat > /etc/systemd/network/dummy0.network << EOF
[Match]
Name=dummy0

[Network]
Bridge=br0
EOF

# Add radxa0 usb gadget network configuration
echo "start configure radxa0 usb gadget network"
gadget_net_fixed_ip_addr=${gadget_net_fixed_ip%/*}
gadget_net_fixed_ip_sub=${gadget_net_fixed_ip%.*}
if [ ! -f /etc/network/interfaces.d/radxa0 ]; then
        cat > /etc/network/interfaces.d/radxa0 << EOF
auto radxa0
allow-hotplug radxa0
iface radxa0 inet static
        address $gadget_net_fixed_ip
        # post-up mount -o remount,ro /home/radxa/Videos && link mass
        # post-down remove mass && mount -o remount,rw /home/radxa/Videos
        up /usr/sbin/dnsmasq --conf-file=/dev/null --no-hosts --bind-interfaces --except-interface=lo --clear-on-reload --strict-order --listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.21,${gadget_net_fixed_ip_sub}.199,12h --dhcp-lease-max=5 --pid-file=/run/dnsmasq-radxa0.pid --dhcp-option=3 --dhcp-option=6
EOF
fi

# Add samba configuration
grep -q "\[config\]" /etc/samba/smb.conf || cat >> /etc/samba/smb.conf << EOF
[Videos]
   path = /home/radxa/Videos
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root

[config]
   path = /config
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root
EOF

# wfb default configuration
cat > /etc/wifibroadcast.cfg << EOF
[common]
wifi_channel = '${wfb_channel}'
wifi_region = '${wfb_region}'

[gs_mavlink]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_mavlink}'

[gs_video]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_video}'

[cluster]

nodes = {
          '127.0.0.1': { 'wlans': ['wlan'], 'wifi_txpower': None, 'server_address': '127.0.0.1' },
          # Remote cards:
          #'192.168.1.123' : { 'wlans': ['wlan0', 'wlan1'], 'wifi_txpower': 'off'},    # rx-only node
          #'192.168.1.155' : { 'wlans': ['wlan0', 'wlan1']},     # rx/tx node
        }

server_address = '${eth0_fixed_ip%/*}'

EOF

systemctl disable gs-init.service

while [ -f /config/before.txt ]; do sleep 2; done
sync
reboot
