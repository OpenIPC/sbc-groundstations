#!/usr/bin/bash

eval $(grep BR2_DEFCONFIG ${O}/.config)
echo "BUILD_CONFIG=$(basename $(basename $BR2_DEFCONFIG) _defconfig)" >> $TARGET_DIR/etc/os-release

DOWNLOAD_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-OpenIPC/sbc-groundstations}/releases/download/buildroot-snapshot/$(basename $(basename $BR2_DEFCONFIG) _defconfig).tar.gz"
# Get version: tag or short SHA, add -dirty if repo is dirty
if git describe --tags --exact-match >/dev/null 2>&1; then
    # Building from a tag
    VERSION=$(git describe --tags)
else
    # Not a tag, use short SHA
    VERSION=$(git rev-parse --short HEAD)
fi

# Check if repo is dirty (has uncommitted changes)
if ! git diff --quiet || ! git diff --cached --quiet; then
    VERSION="${VERSION}-dirty"
fi

cat <<EOF >$TARGET_DIR/etc/os-release
PRETTY_NAME="OpenIPC SBC GS"
NAME="OpenIPC SBC GS"
HOME_URL="https://github.com/OpenIPC/sbc-groundstations"
SUPPORT_URL="https://t.me/+BMyMoolVOpkzNWUy"
BUG_REPORT_URL="https://github.com/OpenIPC/sbc-groundstations/issues"
BUILD_CONFIG=$(basename $(basename $BR2_DEFCONFIG) _defconfig)
UPGRADE=$DOWNLOAD_URL
BUILD_DATE="$(date)"
VERSION="$VERSION"
EOF

cp ${O}/.config $TARGET_DIR/etc/default/br-config

AUTOMOUNT_INSERT_LINE=$(grep -n "# now run any rc scripts" $TARGET_DIR/etc/inittab| cut -d: -f1)
grep -q automount $TARGET_DIR/etc/inittab || sed -i "${AUTOMOUNT_INSERT_LINE}i # Start automount daemon\n::sysinit:/usr/sbin/automount\n" $TARGET_DIR/etc/inittab

grep -q gadget $TARGET_DIR/etc/inittab || echo '
# Start gadget
::sysinit:/usr/sbin/gadget init' >> $TARGET_DIR/etc/inittab

grep -q "Run customize.sh if it exists" $TARGET_DIR/etc/inittab || echo -e '
# Run customize.sh if it exists
::sysinit:/bin/sh -c '\''[ -f /media/dvr/costomize.sh ] && /bin/sh /media/dvr/costomize.sh'\''' >> $TARGET_DIR/etc/inittab

grep -q "framebuffer getty" $TARGET_DIR/etc/inittab || echo '
# framebuffer getty
tty1::askfirst:/sbin/getty -L tty1 0 vt100' >> $TARGET_DIR/etc/inittab
