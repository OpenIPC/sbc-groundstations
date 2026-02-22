include $(sort $(wildcard $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/*/*.mk))
ifeq ($(BR2_PACKAGE_HOST_RKDEVELOPTOOL),y)
include $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/board/radxa/zero3/flash.mk
endif

# we don't need cland on target
define CLANG_DELETE_TARGET
	rm -rf $(TARGET_DIR)/usr/include/clang-c \
		$(TARGET_DIR)/usr/include/clang \
		$(TARGET_DIR)/usr/include/clang \
		$(TARGET_DIR)/usr/lib/libclang* \
		$(TARGET_DIR)/usr/lib/cmake/clang* \
		$(TARGET_DIR)/usr/lib/libclang* \
		$(TARGET_DIR)/usr/lib/clang \
		$(TARGET_DIR)/usr/share/man/man1/scan-build.1 \
		$(TARGET_DIR)/usr/bin/diagtool \
		$(TARGET_DIR)/usr/bin/hmaptool \
		$(TARGET_DIR)/usr/bin/analyze-build \
		$(TARGET_DIR)/usr/bin/scan-build-py \
		$(TARGET_DIR)/usr/bin/intercept-build \
		$(TARGET_DIR)/usr/bin/amdgpu-arch \
		$(TARGET_DIR)/usr/bin/nvptx-arch \
		$(TARGET_DIR)/usr/libexec/intercept-cc \
		$(TARGET_DIR)/usr/libexec/analyze-cc \
		$(TARGET_DIR)/usr/libexec/analyze-c++ \
		$(TARGET_DIR)/usr/libexec/intercept-c++ \
		$(TARGET_DIR)/usr/lib/libear \
		$(TARGET_DIR)/usr/lib/libscanbuild \
		$(TARGET_DIR)/usr/lib/cmake
endef
CLANG_POST_INSTALL_TARGET_HOOKS += CLANG_DELETE_TARGET

# We don't nee samba python
#
# Override to disable Python support
SAMBA4_CONF_OPTS += --disable-python

# Clear Python-related variables
SAMBA4_PYTHON = 

# we do not need libclc on target
define LIBCLC_DELETE_TARGET
	rm -rf $(TARGET_DIR)/usr/share/clc
endef
LIBCLC_POST_INSTALL_TARGET_HOOKS += LIBCLC_DELETE_TARGET
