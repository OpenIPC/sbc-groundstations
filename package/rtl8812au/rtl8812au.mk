################################################################################
# RTL8812AU package (external kernel)
################################################################################

RTL8812AU_VERSION = be10cbbbd9b6b5325554a06a0132985a6b890175
RTL8812AU_SITE = https://github.com/svpcom/rtl8812au
RTL8812AU_SITE_METHOD = git
RTL8812AU_LICENSE = unspecified
RTL8812AU_MODULE_MAKE_OPTS = \
	CONFIG_RTL8812AU=m \
	USER_EXTRA_CFLAGS="-Wno-stringop-overread -Wno-error -Wno-misleading-indentation" \
	TopDIR=$(@D)

$(eval $(kernel-module))

define RTL8812AU_POST_INSTALL_INSTALL_UDEV_RULES
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/rtl8812au/88XXau_wfb.rules $(TARGET_DIR)/etc/udev/rules.d/88XXau_wfb.rules
endef
RTL8812AU_POST_INSTALL_TARGET_HOOKS += RTL8812AU_POST_INSTALL_INSTALL_UDEV_RULES

$(eval $(generic-package))
