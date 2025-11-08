################################################################################
#
# rkdeveloptool
#
################################################################################

HOST_RKDEVELOPTOOL_VERSION = 304f073752fd25c854e1bcf05d8e7f925b1f4e14
HOST_RKDEVELOPTOOL_SITE = $(call github,rockchip-linux,rkdeveloptool,$(HOST_RKDEVELOPTOOL_VERSION))
HOST_RKDEVELOPTOOL_DEPENDENCIES = host-libglib2 host-pkgconf host-libusb host-automake host-autoconf host-libtool

define HOST_RKDEVELOPTOOL_RUN_AUTOGEN
	cd $(@D) && PATH=$(HOST_DIR)/bin:$$PATH ./autogen.sh
endef

HOST_RKDEVELOPTOOL_PRE_CONFIGURE_HOOKS += HOST_RKDEVELOPTOOL_RUN_AUTOGEN

$(eval $(host-autotools-package))
