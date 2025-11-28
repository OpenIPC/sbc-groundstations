################################################################################
# DVRUI package
################################################################################
DVRUI_VERSION = 2.0.0
DVRUI_SITE = https://github.com/JohnDGodwin/radxa_gs_webUI.git
DVRUI_SITE_METHOD = git
DVRUI_LICENSE = GPL-3.0

define DVRUI_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/dvrui/files/S99dvrui \
		$(TARGET_DIR)/etc/init.d/S99dvrui
endef


define DVRUI_INSTALL_TARGET_CMDS
	install -d $(TARGET_DIR)/etc/dvrui/
	cp -r $(@D)/* \
		$(TARGET_DIR)/etc/dvrui/
endef

$(eval $(generic-package))
