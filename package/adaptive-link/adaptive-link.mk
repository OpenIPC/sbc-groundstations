###############################################################################
#
# Adaptive Link
#
###############################################################################

ADAPTIVE_LINK_VERSION = dca368dbaa025472e9836712c52d41bca1a9042b
ADAPTIVE_LINK_SITE = https://github.com/OpenIPC/adaptive-link.git
ADAPTIVE_LINK_SITE_METHOD = git
ADAPTIVE_LINK_INSTALL_TARGET = YES

define ADAPTIVE_LINK_INSTALL_TARGET_CMDS

	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/alink_gs
	$(INSTALL) -m 644 -t $(TARGET_DIR)/etc $(@D)/alink_gs.conf
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(ADAPTIVE_LINK_PKGDIR)/files/S98adaptive-link

	mkdir -p $(TARGET_DIR)/etc/default
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/default $(ADAPTIVE_LINK_PKGDIR)/files/adaptive-link

endef


$(eval $(generic-package))