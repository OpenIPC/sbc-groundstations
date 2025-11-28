A unified OpenIPC groundstation image builder useing Buildroot 2.

# Supported GS Hardware

- RunCam Wifilink
- Emax Wyvern-Link
- Radxa Zero3 (choose one of the above)


# Upgrade

- Copy the `<vrx name>.tar.gz` package to a FAT formatted sd card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the sd card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the eMMC. Use scp, smb or gadget mode and reboot.
- `sysupgrade -u -r` for an online update, see `sysupgrade --help`for more options
- `make ssh-flash` will flash a local build to `BR2_BOARD_HOST` see menuconfig
- `make flash` will flash a local build to the eMMC using rkdeveloptool (maskrom)

# Factory Reset

- Hold the `Right` button pressed during boot.
- Run `firstboot`


# Gadget Mode

- Hold the `Left` button pressed during boot.
- This will enable usb otg gadget mode.

  Via the OTP port you will get:
    * DVR access
    * Serial connection
    * Network connection (SBC is on 192.168.5.1)

# Custom build Linux/WSL2

Custom build relys an buildroot [depencies](https://buildroot.org/downloads/manual/manual.html#requirement) as well as on docker or podman, needed for Radxa's kernel and uboot.

When building in WSL2 make sure your WSL2 can run docker.

```
git clone https://github.com/OpenIPC/sbc-groundstations.git
cd sbc-groundstations
./build.sh
```

Refer to Buildroot's documentation on how to customize your build. [Buildroot](https://buildroot.org/downloads/manual/manual.html)

# Upgrade from older SBC Version (radxa zero3 based)

SBC-GS 2 beta 2 and older will not boot squashfs based systems.
A new bootloader is needed.
The new bootloader will boot SD and eMMC (in that order).

## Option 1

- Boot the old image
- Copy new `<vrx name>_u-boot.bin` to your sbc
- Replace the booloader on the emmc
```
dd if=/tmp/runcam_wifilink_u-boot.bin of=/dev/mmcblk0 seek=64 status=progress
```

## Option 2

- Use RKDevTool/rkdevelop and flash `<vrx name>_emmc_bootloader.img` to the emmc
[How to recover Runcam VRX from a bad flash](https://docs.openipc.org/hardware/runcam/vrx/recoverbadflash/)

This will erase all data on the interal flash.

## Option 3

- Use RKDevTool/rkdevelop and flash SBC-GS to the eMMC

```
dd if=/tmp/<vrx name>_u-boot.bin_sdcard.img of=/dev/mmcblk0 status=progress
```

# u-boot arguments

## eMMC
```
setenv bootargs quiet splash init=/init root=PARTLABEL=rootfs ro rootwait 
mmc dev 0
load mmc 0:1 0x03000000 /boot/Image
load mmc 0:1 0x05000000 /boot/rockchip/rk3566-radxa-zero3.dtb
booti 0x03000000 - 0x05000000
```

## SD
```
setenv bootargs quiet splash init=/init root=PARTLABEL=rootfs ro rootwait
mmc dev 1
load mmc 1:1 0x03000000 /boot/Image
load mmc 1:1 0x05000000 /boot/rockchip/rk3566-radxa-zero3.dtb
booti 0x03000000 - 0x05000000
```
