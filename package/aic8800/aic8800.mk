################################################################################
# AIC8800 package (external kernel)
################################################################################

AIC8800_VERSION = main
AIC8800_SITE = https://github.com/radxa-pkg/aic8800.git
AIC8800_SITE_METHOD = git
AIC8800_LICENSE = GPL-3.0
AIC8800_MODULE_SUBDIRS = src/SDIO/driver_fw/driver/aic8800
AIC8800_MODULE_MAKE_OPTS = CONFIG_AIC_FW_PATH=/lib/firmware/aic8800

$(eval $(kernel-module))

define AIC8800_POST_INSTALL_INSTALL_FIRMWARE
	mkdir -p $(TARGET_DIR)/lib/firmware/aic8800
	mkdir -p $(TARGET_DIR)/etc/modprobe.d/

	cp -a $(@D)/src/SDIO/driver_fw/fw/aic8800D80/* $(TARGET_DIR)/lib/firmware/aic8800

	echo 'options aic8800_fdrv aicwf_dbg_level=1' > $(TARGET_DIR)/etc/modprobe.d/aic8800.conf
endef
AIC8800_POST_INSTALL_TARGET_HOOKS += AIC8800_POST_INSTALL_INSTALL_FIRMWARE

$(eval $(generic-package))
