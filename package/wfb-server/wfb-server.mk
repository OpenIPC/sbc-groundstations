################################################################################
#
# wfb_server
#
################################################################################

WFB_SERVER_VERSION = 7ffc689e3f1194dca79dca4b5b56ee560c0cc3be
WFB_SERVER_SITE = https://github.com/svpcom/wfb-ng.git
WFB_SERVER_SITE_METHOD = git
WFB_SERVER_LICENSE = GPL-3.0
WFB_SERVER_SETUP_TYPE = setuptools

WFB_SERVER_PYTHON_DEPENDENCIES = \
    python \
    libpcap \
    libsodium \
    libevent

WFB_SERVER_BUILD_ENV = \
    VERSION=25.5.1 \
    COMMIT=7ffc689e3f1194dca79dca4b5b56ee560c0cc3be \
    OMIT_DATA_FILES=True

$(eval $(python-package))
