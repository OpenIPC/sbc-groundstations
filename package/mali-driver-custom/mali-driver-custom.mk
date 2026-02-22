# Disable hash checking
MALI_DRIVER_CUSTOM_VERSION = bd00164528dba21ad4b22765b3fd4268f5f814de
MALI_DRIVER_CUSTOM_SITE = $(call github,Kwiboo,mali-rockchip,$(MALI_DRIVER_CUSTOM_VERSION))
MALI_DRIVER_CUSTOM_DEPENDENCIES = linux
MALI_DRIVER_CUSTOM_MODULE_SUBDIRS = driver/product/kernel/drivers/gpu/arm/midgard

$(eval $(kernel-module))
$(eval $(generic-package))