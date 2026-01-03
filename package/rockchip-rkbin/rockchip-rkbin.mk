# Create loader bin to be used by rkdeveloptool
define ROCKCHIP_RKBIN_MERGE_LOADER_BIN
	cd $(@D) && \
		./tools/boot_merger RKBOOT/RK3566MINIALL.ini
endef
ROCKCHIP_RKBIN_POST_BUILD_HOOKS += ROCKCHIP_RKBIN_MERGE_LOADER_BIN