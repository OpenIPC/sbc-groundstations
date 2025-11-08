################################################################################
# DRM_INFO package
################################################################################

DRM_INFO_VERSION = v2.8.0
DRM_INFO_SITE = https://gitlab.freedesktop.org/emersion/drm_info.git
DRM_INFO_SITE_METHOD = git
DRM_INFO_LICENSE = MIT License

$(eval $(meson-package))
