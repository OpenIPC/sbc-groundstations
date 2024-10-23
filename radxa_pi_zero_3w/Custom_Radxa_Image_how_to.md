<h1>How to make a custom Radxa Zero 3 image - A guide to QEMU with ARM64</h1>

  By following these steps, you will be able to successfully modify the Radxa sandbox.img from a linux PC. We need to "log-in" to the image with chroot to make changes. Chrooting into an aarch64 system from an x86_64 machine involves setting up an environment that can emulate aarch64 architecture. To chroot into an ARM64 (aarch64) architecture image on an x86_64 architecture PC, you'll need to use QEMU to emulate the ARM64 environment.

<h3>Step 1 - Set up your host system</h3>

  Debian 12 is recommended. QEMU has a [bug](https://github.com/docker/buildx/issues/1170#issuecomment-2136084089) with later Ubuntu distros when chrooting into an aarch64 environment.
  
  Download the [sandbox.img](https://github.com/OpenIPC/sbc-groundstations/releases) for the radxa. The sandbox.img is identical to the release image, but contains an extra 1.5G of free space for extras.

<h3>Step 2 - Install required packages</h3>

    sudo apt update
    sudo apt install qemu-user-static

<h3>Step 3 - Mount the img file</h3>

    sudo losetup -P /dev/loop0 sandbox.img

    sudo mount /dev/loop0p3 /mnt
    sudo mount /dev/loop0p2 /mnt/boot/efi
    sudo mount /dev/loop0p1 /mnt/config

<h3>Step 4 - Chroot into the img</h3>

    sudo cp /usr/bin/qemu-aarch64-static /mnt/usr/bin

    sudo chroot /mnt qemu-aarch64-static /bin/bash

<h3>Step 5 - Make your changes</h3>

  You are now essentially "logged-in" as the root user inside the radxa sandbox image. Proceed to make your desired changes.

  When done:

      exit

<h3>Step 6 - Clean-up</h3>

    sudo umount --recursive /mnt
    sudo losetup -d /dev/loop0
