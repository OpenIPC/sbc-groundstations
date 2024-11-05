#!/bin/bash

set -ex
echo_red()   { printf "\033[1;31m$*\033[m\n"; }
echo_green() { printf "\033[1;32m$*\033[m\n"; }
echo_blue()  { printf "\033[1;34m$*\033[m\n"; }

build_dir=$(dirname $(readlink -f "$0"))
cd $build_dir

source config

# Checking free space
diskFreeSpace=$(df -P . | tail -1 | awk '{print $4}')
diskNewSize=16 # GB
diskFreeSpaceGB=$(( $diskFreeSpace/1048576 - 4 )) # 4GB for .xz
if [ $diskFreeSpaceGB -lt $diskNewSize ];then
	echo "Error: not enough free space. Not enough $(( $diskNewSize - $diskFreeSpaceGB ))G"
	exit 1
fi

# cleanup build env
mount | grep -q "${build_dir}/${ROOTFS}" && umount -R $ROOTFS
losetupList=$(losetup | grep "${build_dir}" | cut -d ' ' -f 1)
if [ -n "$losetupList" ]; then
	for loopdev in $losetupList; do
		losetup -d $loopdev
	done
fi

apt update
apt install -y qemu-user-static gdisk

IMAGE=$(ls | grep $(basename "$IMAGE_URL" ${IMAGE_URL: -3}) | grep .img$ ) || true # Search basename.img
if [ -f "$IMAGE" ]; then
	echo "Warning: Image '${IMAGE}' file already exist just use it."
else
	# URL or Local file
	if [[ "$IMAGE_URL" == http* ]]; then # if URL
		BASENAME=$(basename "$IMAGE_URL")

		# check if the file has been downloaded before
		if [ -f "$BASENAME" ]; then 
			echo "Warning: Archive file '$BASENAME' already exist just use it"
		else
			wget -q "$IMAGE_URL"
		fi
		IMAGE_ARCHIVE=$BASENAME
	else
		if [[ "$IMAGE_URL" == *.img ]]; then # if .img
			cp $IMAGE_URL .
			IMAGE=$(basename "$IMAGE_URL")
		else
			IMAGE_ARCHIVE=$IMAGE_URL
		fi
	fi

	if [ -n "$IMAGE_ARCHIVE" ]; then # if archive
		# archive unpack
		if file $IMAGE_ARCHIVE | grep -q "XZ compressed"; then
			unxz -vf -T0 "${IMAGE_ARCHIVE}"
		elif file $IMAGE_ARCHIVE | grep -q "7-zip archive data" ; then
			7z x "${IMAGE_ARCHIVE}" -y -sdel
		else
			echo_red "Exception: Unknown archive type '${IMAGE_ARCHIVE}'"
			exit 1
		fi
		rm -f *.sha
		IMAGE=$(ls | grep $(basename "$IMAGE_ARCHIVE" ${IMAGE_ARCHIVE: -3}) | grep .img$) || true # Search image
		if [ $(echo $IMAGE | wc -l) -gt 1 ]; then
			echo_red "Exception: There are more than one files $IMAGE_ARCHIVE"
			echo "$IMAGE"
			exit 1
		fi
	fi
fi

if [ ! -f "$IMAGE"  ]; then
	echo_red "Image '$IMAGE' not found"
	exit 1
fi

# expand disk size
truncate -s ${diskNewSize}G $IMAGE

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
mkdir -p $ROOTFS/home/radxa/SourceCode/SBC-GS
cp -r ../gs ../pics $ROOTFS/home/radxa/SourceCode/SBC-GS

# run build script
# chroot $ROOTFS /bin/bash
cp build.sh $ROOTFS/root/build.sh
chroot $ROOTFS /root/build.sh
rm $ROOTFS/root/build.sh

# add release info
BUILD_DATE=$(date "+%Y-%m-%d")
BUILD_DATETIME=$(date "+%Y-%m-%d %H:%M:%S")
echo "BUILD_DATETIME=\"${BUILD_DATETIME}\"" >> $ROOTFS/etc/gs-release
echo "COMMIT=\"${1}\"" >> $ROOTFS/etc/gs-release

if [[ "$2" == refs/tags/* ]]; then
	VERSION=${2#refs/tags/}
	echo "CHANNEL=\"release\"" >> $ROOTFS/etc/gs-release
else
	VERSION=${1:0:7}
	echo "CHANNEL=\"test\"" >> $ROOTFS/etc/gs-release
fi
echo "VERSION=\"${VERSION}\"" >> $ROOTFS/etc/gs-release
echo "==============show gs-release============"
cat $ROOTFS/etc/gs-release

# umount
umount -R $ROOTFS
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
xz -v -T0 $IMAGE
mv *.xz Radxa-Zero-3_GroundStation_${BUILD_DATE}_${VERSION}.img.xz

exit 0
