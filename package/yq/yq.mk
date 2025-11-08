###############################################################################
#
# YQ
#
###############################################################################

YQ_VERSION = v4.48.1
YQ_SOURCE = yq_linux_arm64.tar.gz
YQ_SITE = https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)
YQ_SITE_METHOD = wget
YQ_INSTALL_TARGET = YES

define YQ_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 $(@D)/yq_linux_arm64 $(TARGET_DIR)/usr/bin/yq
endef
$(eval $(generic-package))
