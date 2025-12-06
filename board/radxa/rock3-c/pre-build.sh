#!/usr/bin/bash
BSP_VERSION=main
BSP_SITE=https://github.com/radxa-repo/bsp.git

if [ ! -d ${BUILD_DIR}/radxa-bsp-${BSP_VERSION} ]
then
    cd ${BUILD_DIR}
    git clone -b ${BSP_VERSION} --recurse-submodules ${BSP_SITE} radxa-bsp-${BSP_VERSION}
    cd radxa-bsp-${BSP_VERSION}
    ./bsp linux rk2410 --no-build
    sed -i 's/^#"rock-3c"/"rock-3c"/' u-boot/latest/fork.conf
    ./bsp u-boot latest rock-3c --no-build
    patch -p1 -i ${BR2_EXTERNAL_OPENIPC_SBC_GS_PATH}/board/radxa/zero3/0001-uboot-compile.patch
    if [ "$CI" = "true" ]; then
        docker image rm -f ghcr.io/radxa-repo/bsp:builder ghcr.io/radxa-repo/bsp:main
    fi
else
    echo "bsp already downloaded, skipping ..."
fi
