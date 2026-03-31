#!/bin/bash
# Generates a target-specific boot.scr from boot.cmd, pre-patching
# __BLKCNT__ and __FILENAME__ for the given platform.
#
# Intended as a Buildroot BR2_ROOTFS_POST_IMAGE_SCRIPT. Add to defconfigs:
#   BR2_ROOTFS_POST_IMAGE_SCRIPT="support/scripts/genimage.sh ${BR2_EXTERNAL_OPENIPC_SBC_GS_PATH}/board/common/gen-boot-scr.sh"
#
# Buildroot passes $BINARIES_DIR as $1 and sets BR2_DEFCONFIG and
# BR2_EXTERNAL_OPENIPC_SBC_GS_PATH as environment variables.

set -e

# $1 is BINARIES_DIR when called by Buildroot
BINARIES_DIR="${BINARIES_DIR:-$1}"
: "${BINARIES_DIR:?BINARIES_DIR must be set}"

# Derive platform name from DEFCONFIG env var (build.sh) or from the
# output directory path (.../output/<platform>_defconfig/images)
if [ -n "${DEFCONFIG:-}" ]; then
    PLATFORM=$(basename "$DEFCONFIG" _defconfig)
else
    PLATFORM=$(basename "$(dirname "$BINARIES_DIR")" | sed 's/_defconfig$//')
fi

# Locate boot.cmd via BR2_EXTERNAL or BR2_EXTERNAL_OPENIPC_SBC_GS_PATH
_EXT="${BR2_EXTERNAL:-${BR2_EXTERNAL_OPENIPC_SBC_GS_PATH}}"
: "${_EXT:?Neither BR2_EXTERNAL nor BR2_EXTERNAL_OPENIPC_SBC_GS_PATH is set}"
BOOT_CMD="${_EXT}/board/common/boot.cmd"

SDCARD_IMG="${BINARIES_DIR}/sdcard.img"
BOOT_SCR="${BINARIES_DIR}/boot.scr"

if [ ! -f "$SDCARD_IMG" ]; then
    echo "gen-boot-scr: ERROR: ${SDCARD_IMG} not found" >&2
    exit 1
fi

# Compute block count: image size in bytes / 512, formatted as U-Boot hex
IMGSIZE=$(stat -c%s "$SDCARD_IMG")
BLKCNT=$(printf "0x%X" $(( IMGSIZE / 512 )))
FILENAME="${PLATFORM}_sdcard.img"

echo "gen-boot-scr: ${FILENAME}: ${IMGSIZE} bytes = ${BLKCNT} blocks"

# Patch __BLKCNT__ and __FILENAME__ placeholders
PATCHED=$(mktemp /tmp/boot.cmd.XXXXXX)
sed -e "s/__BLKCNT__/${BLKCNT}/g" \
    -e "s/__FILENAME__/${FILENAME}/g" \
    "$BOOT_CMD" > "$PATCHED"

# Prefer Buildroot's host mkimage, fall back to system mkimage
MKIMAGE="${BINARIES_DIR}/../host/bin/mkimage"
if [ ! -x "$MKIMAGE" ]; then
    MKIMAGE=$(command -v mkimage 2>/dev/null || true)
fi
if [ -z "$MKIMAGE" ] || [ ! -x "$MKIMAGE" ]; then
    echo "gen-boot-scr: ERROR: mkimage not found (install u-boot-tools or build with Buildroot)" >&2
    rm -f "$PATCHED"
    exit 1
fi

"$MKIMAGE" -C none -A arm -T script -d "$PATCHED" "$BOOT_SCR"
rm -f "$PATCHED"

echo "gen-boot-scr: generated ${BOOT_SCR}"
