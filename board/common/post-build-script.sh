#!/usr/bin/bash

eval $(grep BR2_DEFCONFIG ${O}/.config)
echo "BUILD_CONFIG=$(basename $(basename $BR2_DEFCONFIG) _defconfig)" >> $TARGET_DIR/etc/os-release

DOWNLOAD_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-OpenIPC/sbc-groundstations}/releases/download/latest/$(basename $(basename $BR2_DEFCONFIG) _defconfig).tar.gz"
echo "UPGRADE=$DOWNLOAD_URL" >> $TARGET_DIR/etc/os-release

echo "BUILD_DATE=\"$(date)\"" >> $TARGET_DIR/etc/os-release

cp ${O}/.config $TARGET_DIR/etc/default/br-config

grep -q automount $TARGET_DIR/etc/inittab || echo '
# Start automount daemon
::sysinit:/usr/sbin/automount
' >> $TARGET_DIR/etc/inittab

grep -q gadget $TARGET_DIR/etc/inittab || echo '
# Start gadget
::sysinit:/usr/sbin/gadget init
' >> $TARGET_DIR/etc/inittab