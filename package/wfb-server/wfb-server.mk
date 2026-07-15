################################################################################
#
# wfb_server
#
################################################################################

WFB_SERVER_VERSION = a23fc969d50d1f50bdcac46815848105dd0e88c9
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
    COMMIT=a23fc969d50d1f50bdcac46815848105dd0e88c9 \
    OMIT_DATA_FILES=True

$(eval $(python-package))
