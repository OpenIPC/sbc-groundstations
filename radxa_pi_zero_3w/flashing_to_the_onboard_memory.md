<h1>How to flash the image to the onboard memory</h1>

<h2>Flashing using the Maskrom </h2>

Please refer to the Official Radxa documents on flashing your Radxa's onboard emmc memory with the official tools here: https://docs.radxa.com/en/zero/zero3/low-level-dev/rkdevtool

The bootloader is the rk356x_spl_loader_ddr1056_v1.xx.xxx.bin file found at the bottom of the page.

**note**

RKDevTool is in the Chinese language when first downloaded, however it includes an english ini. After downloading RKDevTool, extract the zip and open config.ini in a text editor. Under [Language] at the top, change Selected from 1 to 2. ![image](https://github.com/OpenIPC/sbc-groundstations/assets/35317840/0bb45f68-b3d3-4901-ad12-6ccad391e0ea)


***

<h2>Flashing with dd</h2>

It is still possible to flash the image to the onboard emmc by booting from the SD card and flashing the onboard memory with the `dd` command.

Download an image of your choice for the Zero 3W. [I recommend this one.](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/v1.33/ubuntu-22.04.3-preinstalled-server-arm64-radxa-zero3.img.xz) (You'll have to boot it up once first or manually expand the filesystem with resize2fs)

Flash that image to an SD card, then transfer the openipc image to a directory inside that image.

Example

		(after flashing the image to the SD card)
  		sudo mount /dev/mmcblk0p2 /mnt
		sudo cp image_we_want_on_the_emmc.img /mnt/media
  		sudo umount /mnt


Boot the system from the SD card and the img we want to flash to the emmc is found in `/media`.

***

Flashing

Prepare the emmc for flashing with fdisk. Type `sudo fdisk /dev/mmcblk0` then delete any partitions that may be present.

Go to the directory you put the img file and enter the following command:

`sudo dd bs=1M if=image_we_want_on_the_emmc.img of=/dev/mmcblk0 status=progress`

When that's done, power down and remove the SD card. The system should now boot from onboard emmc.


***

<h2>Pre-made image for flashing onboard emmc</h2>

[Download this file](https://drive.google.com/file/d/1lww4TroX9bOikmyH1OmMclRrubx-wBQJ/view) and flash it to an SD card using balenaEtcher on windows or dd on linux.

Boot the device.

Login is ubuntu/ubuntu

run `./flash_emmc.sh`

Wait for the image for flash (approx 5.3GB)

shutdown the system and remove the sd card

Power on the system and it should boot the openipc image from emmc
