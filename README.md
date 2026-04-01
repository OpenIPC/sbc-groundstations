A unified OpenIPC ground station image builder using Buildroot 2.

# Supported GS Hardware

- RunCam Wifilink
- Emax Wyvern-Link
- Radxa Zero3 (choose one of the above)
- OpenIPC Bonnet

# Flashing

## Easy Flash eMMC via SD Card (Windows), upgrading from older SBC Images

This method flashes the full image to eMMC by booting from an SD card — supports old sbc versions, no drivers, no special tools required.

**What you need:**
- An SD card (any size, FAT32 formatted)
- `<platform>_sdcard.img` from the [releases](https://github.com/OpenIPC/sbc-groundstations/releases)
- `<platform>_boot.scr` from the same release

**Steps:**

1. **Format the SD card as FAT32.**
   - Open *Disk Management* (`Win + X` → Disk Management), right-click the SD card partition → Format → FAT32.

2. **Copy the files to the SD card.**
   - Copy `<platform>_sdcard.img` to the root of the SD card.
   - Copy `<platform>_boot.scr` to the root of the SD card and **rename it to `boot.scr`**.

3. **Boot from the SD card.**
   - Insert the SD card into the device and power it on.
   - U-Boot will automatically detect and run `boot.scr`, which loads the image and writes it to eMMC.
   - The process takes a few minutes. When complete, the device removes `boot.scr` and the image file from the SD card and reboots into the freshly flashed system.

> **Note:** The device must have a working U-Boot on eMMC. If the eMMC is completely blank or U-Boot is corrupted, use RKDevTool instead — see [Bootloader Only — via Maskrom (RKDevTool / rkdeveloptool)](#bootloader-only--via-maskrom-rkdevtool--rkdeveloptool).


## Boards without eMMC flash

Just use [etcher](https://etcher.balena.io/) to flash the `<platform>_sdcard.img` to an SD card.

## Advanced flashing methods

### Full eMMC Flash via dd (from SD booted system)

Boot from an SD card and write the eMMC image:

```
dd if=/tmp/<vrx name>_sdcard.img of=/dev/mmcblk0 status=progress
```
**Note:** This will erase all data on the internal flash.

### Bootloader Only — via dd (from running system)

Update only the bootloader on the eMMC without touching the rest of the flash:

```
dd if=/tmp/<vrx name>_u-boot.bin of=/dev/mmcblk0 seek=64 status=progress
```

Useful when upgrading from SBC-GS Beta 2 or older, which do not support squashfs-based systems.
Also useful when you want to keep existing data on the eMMC.

### Bootloader Only — via Maskrom (RKDevTool / rkdeveloptool)

Flash `<vrx name>_emmc_bootloader.img` to the eMMC using RKDevTool or rkdeveloptool.

See: [How to recover RunCam VRX from a bad flash](https://docs.openipc.org/hardware/runcam/vrx/recoverbadflash/)

**Note:** This will erase all data on the internal flash.

# Upgrade

Once flashed, the Buildroot image can update itself via several ways:

- Copy the `<vrx name>.tar.gz` package to a FAT-formatted SD card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the SD card and reboot.
- Copy the `<vrx name>.tar.gz` package to the `DVR` partition on the eMMC. Use `scp`, SMB, or gadget mode and reboot.
- Use `sysupgrade -u -r` for an online update. See `sysupgrade --help` for more options.
- Use `./build.sh ssh-flash` to flash a local build to `BR2_BOARD_HOST`. See menuconfig.
- Use `./build.sh flash` to flash a local build to the eMMC using `rkdeveloptool` (maskrom).

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

Custom builds rely on Buildroot [dependencies](https://buildroot.org/downloads/manual/manual.html#requirement).

```
git clone https://github.com/OpenIPC/sbc-groundstations.git
cd sbc-groundstations
./build.sh
```

Refer to Buildroot's documentation for instructions on customizing your build: [Buildroot](https://buildroot.org/downloads/manual/manual.html)

# Dual Boot (Older RadxaOS based images)

There is a DTB naming mismatch in u-boot versions between the sbc-gs and older RadxaOS based images e.g. Ruby.
The fix is to copy the correct DTB into the Ruby partition once after installing:

```
# Boot to sbc-gs and enter these commands:
mkdir -p /mnt/ruby
mount /dev/mmcblk1p3 /mnt/ruby
cp /boot/rockchip/rk3566-radxa-zero-3w-aic8800ds2.dtb /mnt/ruby/usr/lib/linux-image-5.10.160-34-rk356x/rockchip/rk3566-radxa-zero-3w.dtb
reboot
```

# CC Edition Maintained by @zhouruixi

See the CC branch
* Radxa zero 3W/E
  [v0.9-beta](https://github.com/zhouruixi/SBC-GS/releases/tag/v0.9-beta)
