#!/bin/bash

set -e
source config

apt update
apt install -y qemu-user-static

if [[ "$IMAGE_URL" == "/*" ]]; then
	cp $IMAGE_URL .
else
	wget -q "$IMAGE_URL"
fi
IMAGE=$(basename "$IMAGE_URL" .xz)
unxz -T0 ${IMAGE}.xz

# expand disk size
truncate -s 16G $IMAGE

LOOPDEV=$(losetup -P --show -f $IMAGE)
ROOT_PART=$(sgdisk -p $LOOPDEV | grep "rootfs" | tail -n 1 | tr -s ' ' | cut -d ' ' -f 2)
ROOT_DEV=${LOOPDEV}p${ROOT_PART}

# move second/backup GPT header to end of disk
sgdisk -ge $LOOPDEV

# refresh partition table
# kpartx -a /dev/loop

# expand root patition size
parted -s $LOOPDEV resizepart $ROOT_PART 100%

# expand rootfs
e2fsck -yf $ROOT_DEV
resize2fs $ROOT_DEV

# mount rootfs and config
[ -d $ROOTFS ] || mkdir $ROOTFS
mount $ROOT_DEV $ROOTFS
mount ${LOOPDEV}p1 $ROOTFS/config
mount -t proc /proc $ROOTFS/proc
mount -t sysfs /sys $ROOTFS/sys
mount -o bind /dev $ROOTFS/dev
mount -o bind /run $ROOTFS/run
mount -t devpts devpts $ROOTFS/dev/pts

# copy gs code to target rootfs
mkdir -p $ROOTFS/home/radxa/SourceCode
cp -r ../gs $ROOTFS/home/radxa/SourceCode

# run build script
# chroot $ROOTFS /bin/bash
cp build.sh $ROOTFS/root/build.sh
chroot $ROOTFS /root/build.sh
rm $ROOTFS/root/build.sh

# umount
umount $ROOTFS/dev/pts
umount $ROOTFS/run
umount $ROOTFS/dev
umount $ROOTFS/sys
umount $ROOTFS/proc
umount $ROOTFS/config
umount $ROOTFS
rm -r $ROOTFS

# shrink image
SECTOR_SIZE=$(sgdisk -p $ROOT_DEV | grep -oP "(?<=: )\d+(?=/)")
START_SECTOR=$(sgdisk -i $ROOT_PART $LOOPDEV | grep "First sector:" | cut -d ' ' -f 3)
TOTAL_BLOCKS=$(tune2fs -l $ROOT_DEV | grep '^Block count:' | tr -s ' ' | cut -d ' ' -f 3)
e2fsck -yf $ROOT_DEV
TARGET_BLOCKS=$(resize2fs -P $ROOT_DEV 2> /dev/null | cut -d ' ' -f 7)
BLOCK_SIZE=$(tune2fs -l $ROOT_DEV | grep '^Block size:' | tr -s ' ' | cut -d ' ' -f 3)
resize2fs -M $ROOT_DEV
TOTAL_BLOCKS_SHRINKED=$(sudo tune2fs -l "$ROOT_DEV" | grep '^Block count:' | tr -s ' ' | cut -d ' ' -f 3)
sync $ROOT_DEV
NEW_SIZE=$(( $START_SECTOR * $SECTOR_SIZE + $TARGET_BLOCKS * $BLOCK_SIZE ))
cat << EOF | parted ---pretend-input-tty $LOOPDEV > /dev/null 2>&1
resizepart $ROOT_PART 
${NEW_SIZE}B
yes
EOF
END_SECTOR=$(sgdisk -i $ROOT_PART $LOOPDEV | grep "Last sector:" | cut -d ' ' -f 3)
FINAL_SIZE=$(( ($END_SECTOR + 34) * $SECTOR_SIZE ))

losetup -d $LOOPDEV
truncate --size=$FINAL_SIZE $IMAGE > /dev/null
sgdisk -ge $IMAGE > /dev/null
sgdisk -v $IMAGE > /dev/null

echo "Image shrunked from ${TOTAL_BLOCKS} to ${TOTAL_BLOCKS_SHRINKED}."

# compression image and rename xz file
xz -T0 $IMAGE
mv *.xz Radxa-zero-3_GroundStation_${VERSION}.img.xz

exit 0
