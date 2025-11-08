#!/bin/sh

key="$1"

# check if we are in gadet mode
[ -d /sys/kernel/config/usb_gadget/g1 ] && exit 1

# Primary and fallback block devices
ROOT_DEV=$(readlink -f /dev/disk/by-partlabel/rootfs)
DEV=""

if [ "$ROOT_DEV" = "/dev/mmcblk0p1" ]; then  # booted from emmc
    # First try: DVR partition on eMMC
    if [ -b /dev/mmcblk0p3 ]; then
        DEV="/dev/mmcblk0p3"
    fi
    
    # Prefer: SD card's VFAT partition
    if [ -b /dev/mmcblk1p1 ] && file -s /dev/mmcblk1p1 | grep -q 'FAT'; then
        DEV="/dev/mmcblk1p1"
    fi
elif [ "$ROOT_DEV" = "/dev/mmcblk1p1" ]; then  # booted from sd
    # Use SD card's VFAT partition as DVR
    if [ -b /dev/mmcblk1p3 ] && file -s /dev/mmcblk1p3 | grep -q 'FAT'; then
        DEV="/dev/mmcblk1p3"
    fi
fi

if [ -b "$DEV" ]; then
    echo "-fstype=vfat :$DEV"
else
    exit 1
fi