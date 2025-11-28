#!/usr/bin/bash
BSP_VERSION=main
BSP_SITE=https://github.com/radxa-repo/bsp.git

if [ ! -d ${BUILD_DIR}/radxa-bsp-${BSP_VERSION} ]
then
    cd ${BUILD_DIR}
    git clone -b ${BSP_VERSION} --recurse-submodules ${BSP_SITE} radxa-bsp-${BSP_VERSION}
    cd radxa-bsp-${BSP_VERSION}
    ./bsp linux rk356x --no-build
    sed -i 's/^#"radxa-zero3"/"radxa-zero3"/' u-boot/latest/fork.conf
    ./bsp u-boot latest radxa-zero3 --no-build
    patch -p1 -i ${BR2_EXTERNAL_OPENIPC_SBC_GS_PATH}/board/runcam/wifilink/0001-uboot-compile.patch
else
    echo "bsp already downloaded, skipping ..."
fi
