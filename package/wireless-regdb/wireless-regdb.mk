WIRELESS_REGDB_DEPENDENCIES = host-python3 host-openssl

define WIRELESS_REGDB_BUILD_CMDS
	patch -p1 -d $(@D) -i ${BR2_EXTERNAL_OPENIPC_SBC_GS_PATH}/package/wireless-regdb/0001-add-country-OO-for-wifi-fpv.patch
	$(MAKE) -C $(@D) regulatory.db regulatory.db.p7s
endef
