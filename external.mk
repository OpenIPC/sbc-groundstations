include $(sort $(wildcard $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/*/*.mk))
ifeq ($(BR2_PACKAGE_HOST_RKDEVELOPTOOL),y)
include $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/board/radxa/zero3/flash.mk
endif
