A unified OpenIPC ground station image builder using Buildroot 2.

# Supported GS Hardware

- RunCam Wifilink
- Emax Wyvern-Link
- Radxa Zero3 (choose one of the above)

# Upgrade

- Copy the `<vrx name>.tar.gz` package to a FAT-formatted SD card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the SD card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the eMMC. Use `scp`, SMB, or gadget mode and reboot.
- Use `sysupgrade -u -r` for an online update. See `sysupgrade --help` for more options.
- Use `make ssh-flash` to flash a local build to `BR2_BOARD_HOST`. See menuconfig.
- Use `make flash` to flash a local build to the eMMC using `rkdeveloptool` (maskrom).
- Flash `<vrx name>_sdcard.img` using RKDevTool, see: [Wiki](https://docs.openipc.org/hardware/runcam/vrx/recoverbadflash/])

# Factory Reset

- Hold the `Right` button during boot.
- Run `firstboot`.

# Gadget Mode

- Hold the `Left` button during boot to enable USB OTG gadget mode.

  Via the OTG port, you will get:
  - DVR access
  - Serial connection
  - Network connection (SBC is on `192.168.5.1`)

# Custom Build (Linux/WSL2)

Custom builds rely on Buildroot [dependencies](https://buildroot.org/downloads/manual/manual.html#requirement), as well as Docker or Podman, which are needed for Radxa's kernel and U-Boot.

When building in WSL2, ensure your WSL2 instance can run Docker.

```
git clone https://github.com/OpenIPC/sbc-groundstations.git
cd sbc-groundstations
./build.sh
```

Refer to Buildroot's documentation for instructions on customizing your build: [Buildroot](https://buildroot.org/downloads/manual/manual.html)

# Upgrade from Older SBC Version (Radxa Zero3 Based)

SBC-GS 2 Beta 2 and older versions will not boot squashfs-based systems. A new bootloader is required. The new bootloader will boot from the SD card and eMMC (in that order).

## Option 1

- Boot the old image.
- Copy the new `<vrx name>_u-boot.bin` to your SBC.
- Replace the bootloader on the eMMC:
  ```
  dd if=/tmp/runcam_wifilink_u-boot.bin of=/dev/mmcblk0 seek=64 status=progress
  ```

## Option 2

- Use RKDevTool/rkdeveloptool and flash `<vrx name>_emmc_bootloader.img` to the eMMC.

  [How to recover RunCam VRX from a bad flash](https://docs.openipc.org/hardware/runcam/vrx/recoverbadflash/)

  **Note:** This will erase all data on the internal flash.

## Option 3

- Use RKDevTool/rkdeveloptool and flash SBC-GS to the eMMC:
  ```
  dd if=/tmp/<vrx name>_sdcard.img of=/dev/mmcblk0 status=progress
  ```

# U-Boot Arguments

## eMMC
```
setenv bootargs quiet splash init=/init root=PARTLABEL=rootfs ro rootwait 
mmc dev 0
load mmc 0:1 0x03000000 /boot/Image
load mmc 0:1 0x05000000 /boot/rockchip/rk3566-radxa-zero3.dtb
booti 0x03000000 - 0x05000000
```

## SD Card
```
setenv bootargs quiet splash init=/init root=PARTLABEL=rootfs ro rootwait
mmc dev 1
load mmc 1:1 0x03000000 /boot/Image
load mmc 1:1 0x05000000 /boot/rockchip/rk3566-radxa-zero3.dtb
booti 0x03000000 - 0x05000000
```
