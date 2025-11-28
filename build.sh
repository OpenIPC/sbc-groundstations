#!/bin/bash

# Useful make targets
# make menuconfig
# make uboot-menuconfig
# make savedefconfig
# make runcam_wifilink_defconfig
# make O=/tmp/buildroot-sbc-gs-output BR2_EXTERNAL=$PWD -C buildroot all

set -e

# Default configuration
BUILDROOT_VERSION="2025.08.1"
BUILDROOT_SOURCE="https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz"
BUILDROOT_DIR="buildroot"
BUILDROOT_TARBALL="buildroot-${BUILDROOT_VERSION}.tar.gz"
DEFCONFIG="${DEFCONFIG:-runcam_wifilink_defconfig}"
mkdir -p board/local/overlay/etc/network/interfaces.d

# Parse command line options
OUTPUT_DIR="$(pwd)/output"
TARGET="all"
while getopts "o:h" opt; do
    case $opt in
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        h)
            echo "Usage: $0 [-o output-dir]  [target, default all]"
            echo "  -o output-dir  Buildroot O= output directory"
            echo "  -h             Show this help"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))
if [ $# -gt 0 ]; then
    TARGET="$1"
fi

# Function to download and extract Buildroot
setup_buildroot() {
    if [ ! -d "$BUILDROOT_DIR" ]; then
        echo "Downloading Buildroot ${BUILDROOT_VERSION}..."
        if command -v wget >/dev/null 2>&1; then
            wget "$BUILDROOT_SOURCE"
        elif command -v curl >/dev/null 2>&1; then
            curl -O "$BUILDROOT_SOURCE"
        else
            echo "Error: Neither wget nor curl found. Please install one of them."
            exit 1
        fi
        
        echo "Extracting Buildroot..."
        tar -xzf "$BUILDROOT_TARBALL"
        rm "$BUILDROOT_TARBALL"
        mv "buildroot-${BUILDROOT_VERSION}" "$BUILDROOT_DIR"
    else
        echo "Buildroot source already exists at $BUILDROOT_DIR"
    fi
}

# Function to build the project
build_project() {

    local build_cmd=""
    
    echo "Using output directory: $OUTPUT_DIR/$DEFCONFIG"
    build_cmd="make -C $BUILDROOT_DIR O=$OUTPUT_DIR/$DEFCONFIG"
    mkdir -p "$OUTPUT_DIR"
    
    # Check if we're in a BR_EXTERNAL directory
    if [ ! -f "external.mk" ] && [ ! -f "external.desc" ]; then
        echo "Warning: This doesn't appear to be a BR_EXTERNAL directory"
        echo "Make sure you're running this script from your BR_EXTERNAL project root"
    fi
    
    # Set BR2_EXTERNAL to current directory
    export BR2_EXTERNAL=$(pwd)
    
    echo "Building with BR2_EXTERNAL=$BR2_EXTERNAL"
    
    # Run defconfig
    if [ $TARGET != "savedefconfig" ]
    then
        echo "Running defconfig: $DEFCONFIG"
        $build_cmd "$DEFCONFIG"
    fi
    
    # Run make
    echo "Starting build..."
    $build_cmd $TARGET

    if [ $TARGET = "all" ]
    then
        cd $OUTPUT_DIR/$DEFCONFIG/images
        cp u-boot-rockchip.bin u-boot.bin
        for file in sdcard.img u-boot.bin emmc_bootloader.img rootfs.squashfs  ; do
        if [ -f "$file" ]; then
            cp "$file" "$(basename $DEFCONFIG _defconfig)_${file}"
        fi
        done
        md5sum rootfs.squashfs > rootfs.squashfs.md5sum
        md5sum u-boot.bin > u-boot.bin.md5sum
        tar zcvf "$(basename $DEFCONFIG _defconfig)".tar.gz rootfs.squashfs u-boot.bin *.md5sum
        cd -
    fi

    echo "Build completed successfully!"
}

# Main execution
main() {
    echo "Starting Buildroot build for $DEFCONFIG"
    
    # Setup Buildroot if needed
    setup_buildroot
    
    # Build the project
    build_project
}

# Run main function
main "$@"