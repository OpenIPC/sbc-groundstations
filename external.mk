include $(sort $(wildcard $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/*/*.mk))
ifeq ($(BR2_PACKAGE_HOST_RKDEVELOPTOOL),y)
include $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/board/radxa/zero3/flash.mk
endif

# PixelPilot renders with GLES on the Mali GPU through Mesa's panfrost driver.
# Panfrost only depends on host-llvm with buildroot-patches/ applied (build.sh
# does that); on an unpatched Buildroot it still depends on target LLVM and
# kconfig silently drops it from these defconfigs, leaving Mesa without a GPU
# driver.
ifeq ($(BR_BUILDING),y)
ifeq ($(BR2_PACKAGE_MESA3D):$(BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_PANFROST),y:)
$(error mesa3d is enabled without the panfrost driver; build with build.sh so buildroot-patches/ get applied to the Buildroot tree)
endif
endif

# We don't nee samba python
#
# Override to disable Python support
SAMBA4_CONF_OPTS += --disable-python

# Clear Python-related variables
SAMBA4_PYTHON = 
