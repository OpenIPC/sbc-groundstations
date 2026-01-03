###############################################################################
#
# pixelpilot
#
###############################################################################

PIXELPILOT_VERSION=0fc9cc8f66310c8efcc81fa9fb24449212f73480
PIXELPILOT_SITE=https://github.com/OpenIPC/PixelPilot_rk.git
PIXELPILOT_SITE_METHOD = git
PIXELPILOT_GIT_SUBMODULES = YES
PIXELPILOT_INSTALL_STAGING = NO
PIXELPILOT_INSTALL_TARGET = YES
PIXELPILOT_DEPENDENCIES = rockchip-mpp libdrm cairo spdlog json-for-modern-cpp yaml-cpp libgpiod gstreamer1 gst1-plugins-base msgpack

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
	mkdir -p $(TARGET_DIR)/usr/share/fonts

	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/pixelpilot \
		$(TARGET_DIR)/etc/default/pixelpilot

	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/pixelpilot/files/osd.json \
		$(TARGET_DIR)/etc/pixelpilot/osd.json

	$(INSTALL) -D -m 0755 $(PIXELPILOT_PKGDIR)/files/gsmenu.sh \
		$(TARGET_DIR)/usr/bin/gsmenu.sh

	$(INSTALL) -D -m 0644 $(PIXELPILOT_PKGDIR)/files/Roboto-Regular.ttf \
		$(TARGET_DIR)/usr/share/fonts/Roboto-Regular.ttf

endef

PIXELPILOT_POST_INSTALL_TARGET_HOOKS += PIXELPILOT_POST_INSTALL_TARGET_HOOK

$(eval $(cmake-package))
