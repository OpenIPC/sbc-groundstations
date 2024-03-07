<h1>How to flash the image to the onboard memory</h1>


Currently the flashrom feature from Radxa is more trouble than it is worth. However it is still possible to flash the image to the onboard emmc. We do this by booting from the SD card and flashing the onboard memory with the `dd` command.

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
