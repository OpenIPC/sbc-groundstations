LIBRGA_VERSION = linux-rga-multi
LIBRGA_SITE = https://gitee.com/nyanmisaka/rga.git
LIBRGA_SITE_METHOD = git
LIBRGA_INSTALL_STAGING = YES
LIBRGA_INSTALL_TARGET = YES

#$(eval $(cmake-package))
$(eval $(meson-package))

