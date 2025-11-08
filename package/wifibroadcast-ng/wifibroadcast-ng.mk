################################################################################
#
# wifibroadcast-ng
#
################################################################################

WIFIBROADCAST_NG_VERSION = 7ffc689e3f1194dca79dca4b5b56ee560c0cc3be
WIFIBROADCAST_NG_SITE = https://github.com/svpcom/wfb-ng.git
WIFIBROADCAST_NG_SITE_METHOD = git
WIFIBROADCAST_NG_LICENSE = GPL-3.0

WIFIBROADCAST_NG_DEPENDENCIES = libpcap libsodium libevent

define WIFIBROADCAST_NG_BUILD_CMDS
	$(MAKE) CC=$(TARGET_CC) CXX=$(TARGET_CXX) LDFLAGS=-s -C $(@D) all_bin
endef

define WIFIBROADCAST_NG_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 -d $(TARGET_DIR)/etc
	$(INSTALL) -m 644 -t $(TARGET_DIR)/etc $(WIFIBROADCAST_NG_PKGDIR)/files/gs.key

	$(INSTALL) -m 755 -d $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(WIFIBROADCAST_NG_PKGDIR)/files/S98wifibroadcast

	$(INSTALL) -m 755 -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/wfb_rx
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/wfb_tx
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/wfb_tx_cmd
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/wfb_tun
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/wfb_keygen

	mkdir -p $(TARGET_DIR)/etc/default
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/default $(@D)/scripts/default/wifibroadcast

	echo 'WIFIBROADCAST_ENABLED=true' >> $(TARGET_DIR)/etc/default/wifibroadcast

	mkdir -p $(TARGET_DIR)/etc/sysctl.d
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/sysctl.d/ $(@D)/scripts/sysctl/98-wifibroadcast.conf

	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/ $(WIFIBROADCAST_NG_PKGDIR)/files/wifibroadcast.cfg

	mkdir -p $(TARGET_DIR)/etc/modprobe.d
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/modprobe.d $(WIFIBROADCAST_NG_PKGDIR)/files/wfb.conf

	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(WIFIBROADCAST_NG_PKGDIR)/files/wfb-nics

endef

$(eval $(generic-package))