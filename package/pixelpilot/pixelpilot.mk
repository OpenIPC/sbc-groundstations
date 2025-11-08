PIXELPILOT_VERSION=6ffe03d3dc1777149b3724ef0d4b4c3370477189
PIXELPILOT_SITE=https://github.com/henkwiedig/PixelPilot_rk.git
PIXELPILOT_SITE_METHOD = git
PIXELPILOT_GIT_SUBMODULES = YES
PIXELPILOT_INSTALL_STAGING = NO
PIXELPILOT_INSTALL_TARGET = YES
PIXELPILOT_DEPENDENCIES = rockchip-mpp

PIXELPILOT_CMAKE_OPTS += -DCMAKE_PREFIX_PATH=$(STAGING_DIR)/usr

define PIXELPILOT_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/S99pixelpilot \
		$(TARGET_DIR)/etc/init.d/S99pixelpilot

	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/pixelpilot.sh \
		$(TARGET_DIR)/usr/bin/pixelpilot.sh
endef

define PIXELPILOT_POST_INSTALL_TARGET_HOOK
	mkdir -p $(TARGET_DIR)/etc/default
	mkdir -p $(TARGET_DIR)/etc/pixelpilot

	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/pixelpilot \
		$(TARGET_DIR)/etc/default/pixelpilot

	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/osd.json \
		$(TARGET_DIR)/etc/pixelpilot/osd.json

	$(INSTALL) -D -m 0755 $(PIXELPILOT_PKGDIR)/files/gsmenu.sh \
		$(TARGET_DIR)/usr/bin/gsmenu.sh

endef

PIXELPILOT_POST_INSTALL_TARGET_HOOKS += PIXELPILOT_POST_INSTALL_TARGET_HOOK

$(eval $(cmake-package))