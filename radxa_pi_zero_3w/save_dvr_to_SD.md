<h1>How to save DVR files to the SD card slot (for emmc only)</h1>

If your Radxa OpenIPC image is running from onboard emmc, the sd card slot is free for us to insert an sd card and save dvr files.

* Format an sd card to FAT32.
* Edit `/etc/fstab` to mount the sd card to `/media` where the dvr files are normally stored. (older images used the directory `/home/radxa/Videos` edit accordingly)

***

`sudo nano /etc/fstab`

and edit the file to include the following line:

`/dev/mmcblk1p1  /media  vfat  defaults  0  2`

It should look something along the lines of this:

![fstab](https://github.com/user-attachments/assets/55ad1323-06b2-4180-a644-67f66bccc65f)

***

