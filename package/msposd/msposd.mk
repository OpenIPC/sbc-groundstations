###############################################################################
#
# msposd
#
###############################################################################

MSPOSD_VERSION = 694221a59e4b17fd4324d24337a7bf3293127dcf
MSPOSD_SITE = https://github.com/OpenIPC/msposd.git
MSPOSD_SITE_METHOD = git
MSPOSD_INSTALL_TARGET = YES

define MSPOSD_INSTALL_TARGET_CMDS

	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/msposd
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(MSPOSD_PKGDIR)/files/S98msposd

	mkdir -p $(TARGET_DIR)/etc/default
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/default $(MSPOSD_PKGDIR)/files/msposd

	mkdir -p $(TARGET_DIR)/usr/share/fonts
	
	$(INSTALL) -m 755 $(@D)/fonts/original/betaflight/font_hd.png $(TARGET_DIR)/usr/share/fonts/font_hd.png
	$(INSTALL) -m 755 $(@D)/fonts/original/betaflight/font.png $(TARGET_DIR)/usr/share/fonts/font.png

	$(INSTALL) -m 755 $(@D)/fonts/font_ardu_hd.png $(TARGET_DIR)/usr/share/fonts/font_ardu_hd.png
	$(INSTALL) -m 755 $(@D)/fonts/font_ardu.png $(TARGET_DIR)/usr/share/fonts/font_ardu.png

	$(INSTALL) -m 755 $(@D)/fonts/original/betaflight/font_hd.png  $(TARGET_DIR)/usr/share/fonts/font_btfl_hd.png
	$(INSTALL) -m 755 $(@D)/fonts/original/betaflight/font.png $(TARGET_DIR)/usr/share/fonts/font_btfl.png

	$(INSTALL) -m 755 $(@D)/fonts/original/inav/font_hd.png $(TARGET_DIR)/usr/share/fonts/font_inav_hd.png
	$(INSTALL) -m 755 $(@D)/fonts/original/inav/font.png $(TARGET_DIR)/usr/share/fonts/font_inav.png

endef

define MSPOSD_BUILD_CMDS

	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DRV=$(@D) OUTPUT=$(@D)/msposd CC=$(TARGET_CC) br-rockchip

endef

$(eval $(generic-package))