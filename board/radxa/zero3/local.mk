LINUX_OVERRIDE_SRCDIR=$(BUILD_DIR)/radxa-bsp-main/.src/linux
LINUX_CFLAGS = "-Wno-enum-int-mismatch"

define BUSYBOX_APPLY_CUSTOM_PATCHES
    $(APPLY_PATCHES) $(@D) $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/busybox \*.patch
endef

BUSYBOX_POST_PATCH_HOOKS += BUSYBOX_APPLY_CUSTOM_PATCHES

# We have tight space constraints on the gitlab runners
ifeq ($(CI),true)

# Remove unused build artifacs after install
define CI_CLEANUP_HOOK
	@echo "CI: Cleaning build directory to save space"
	$(RM) -r $(@D)/*
endef
LINUX_FIRMWARE_POST_INSTALL_IMAGES_HOOKS += CI_CLEANUP_HOOK
SAMBA4_POST_INSTALL_TARGET_HOOKS += CI_CLEANUP_HOOK

# Remove unused src tree
define CI_CLEANUP_SRC_HOOK
	@echo "CI: Cleaning src directory to save space"
	$(RM) -r $(SRCDIR)
endef
LINUX_POST_RSYNC_HOOKS += CI_CLEANUP_SRC_HOOK

endif
