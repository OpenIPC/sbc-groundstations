# boot.cmd - Flash sdcard.img to eMMC
# This is a template. Do not use directly — generate boot.scr via:
#   board/common/gen-boot-scr.sh
# Placeholders __FILENAME__ and __BLKCNT__ are patched at build time.

# Set source location (SD card, first partition)
setenv src_device mmc 1:1
setenv filename __FILENAME__

# eMMC device (typically mmc 0)
setenv emmc_device 0

echo "========================================"
echo "Rockchip U-Boot Flasher"
echo "========================================"
echo "Source: ${src_device}/${filename}"
echo "Target: eMMC ${emmc_device}"
echo ""

# Read the file from SD card
echo "Reading ${filename} from SD card..."
if load ${src_device} ${loadaddr} ${filename}; then
    echo "OK - Loaded ${filesize} bytes to address ${loadaddr}"
else
    echo "ERROR: Failed to read ${filename} from ${src_device}"
    exit
fi

# Switch to eMMC device
echo ""
echo "Switching to eMMC device ${emmc_device}..."
if mmc dev ${emmc_device}; then
    echo "OK - Now using eMMC"
else
    echo "ERROR: Failed to switch to eMMC device ${emmc_device}"
    exit
fi

# Write to eMMC
# blkcnt is pre-computed at build time (image bytes / 512, in hex)
# mmc write arguments are always interpreted as hex by U-Boot
setenv blkcnt __BLKCNT__
echo ""
echo "Writing ${blkcnt} blocks to eMMC ..."
mmc write ${loadaddr} 0x0 ${blkcnt}

if test $? -eq 0; then
    echo ""
    echo "========================================"
    echo "SUCCESS: Wrote ${blkcnt} sectors"
    echo "Image written to eMMC!"
    echo "========================================"
else
    echo ""
    echo "ERROR: Write failed!"
fi
fatrm ${src_device} boot.scr
if test $? -eq 0; then
    echo ""
    echo "========================================"
    echo "SUCCESS: Removal of boot.scr"
    echo "========================================"
else
    echo ""
    echo "ERROR: Remove of boot.scr failed!"
fi
fatrm ${src_device} ${filename}
if test $? -eq 0; then
    echo ""
    echo "========================================"
    echo "SUCCESS: Removal of ${filename}"
    echo "========================================"
else
    echo ""
    echo "ERROR: Remove of ${filename} failed!"
fi