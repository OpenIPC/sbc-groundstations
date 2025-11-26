# Paths
RKTOOL          = $(HOST_DIR)/bin/rkdeveloptool
RKBIN_BUILD_DIR  = $(BUILD_DIR)/rockchip-rkbin-custom
LOADER_BIN       = $(RKBIN_BUILD_DIR)/bin/rk35/rk356x_spl_loader_v1.23.114.bin

FLASH_IMG        = $(BINARIES_DIR)/sdcard.img
ROOTFS_IMG       = $(BINARIES_DIR)/rootfs.squashfs
UBOOT_IMG        = $(BINARIES_DIR)/u-boot-rockchip.bin

# SSH settings
SSH_USER         = root
SSH_HOST        := $(shell echo $(BR2_BOARD_HOST) | tr -d '"')
SSH_PASS         = 12345

# -----------------------------
# Direct USB flash using rkdeveloptool
# -----------------------------
flash:
	@if [ ! -f "$(LOADER_BIN)" ]; then \
		echo "ERROR: Loader not found: $(LOADER_BIN)"; \
		exit 1; \
	fi

	@echo "Checking for Rockchip device..."
	@$(RKTOOL) ld >/dev/null 2>&1 || { \
		echo "No Rockchip device detected in MASKROM/LOADER mode."; \
		exit 1; \
	}

	@echo "Loading SPL loader..."
	$(RKTOOL) db $(LOADER_BIN)

	@echo "Writing SD card image..."
	$(RKTOOL) wl 0x0 $(FLASH_IMG)

	@echo "Flash completed successfully."

# -----------------------------
# SSH-based flash
# -----------------------------
ssh-flash:
	@echo "Sending rootfs: $(ROOTFS_IMG) ..."
	sshpass -p $(SSH_PASS) scp $(ROOTFS_IMG) $(SSH_USER)@$(SSH_HOST):/tmp

	@echo "Sending u-boot: $(UBOOT_IMG) ..."
	sshpass -p $(SSH_PASS) scp $(UBOOT_IMG) $(SSH_USER)@$(SSH_HOST):/tmp

	@echo "Running sysupgrade..."
	sshpass -p $(SSH_PASS) ssh $(SSH_USER)@$(SSH_HOST) \
		sysupgrade --uboot=/tmp/$(notdir $(UBOOT_IMG)) --rootfs=/tmp/$(notdir $(ROOTFS_IMG))

	@echo "SSH flash completed successfully."

.PHONY: flash ssh-flash
