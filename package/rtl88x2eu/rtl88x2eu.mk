################################################################################
# RTL88X2EU package (external kernel)
################################################################################

RTL88X2EU_VERSION = a8fe2bb8b01650fa451ae7c38bf641259f43a83e
RTL88X2EU_SITE = https://github.com/libc0607/rtl88x2eu-20230815.git
RTL88X2EU_SITE_METHOD = git
RTL88X2EU_LICENSE = unspecified
RTL88X2EU_MODULE_MAKE_OPTS = \
	CONFIG_RTL8822EU=m \
	USER_EXTRA_CFLAGS="-Wno-stringop-overread -Wno-error -Wno-misleading-indentation"

$(eval $(kernel-module))

define RTL88X2EU_POST_INSTALL_INSTALL_UDEV_RULES
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/rtl88x2eu/88x2eu.rules $(TARGET_DIR)/etc/udev/rules.d/88x2eu.rules
endef
RTL88X2EU_POST_INSTALL_TARGET_HOOKS += RTL88X2EU_POST_INSTALL_INSTALL_UDEV_RULES

$(eval $(generic-package))
