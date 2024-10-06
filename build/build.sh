#!/bin/bash
# Must using Ubuntu 22.04，24.04 had issue with qemu-aarch64-static
# script running in target debian arm64 OS

set -e

export LANGUAGE=POSIX
export LC_ALL=POSIX
export LANG=POSIX

# Remove unnecessary package [ need remove more unnecessary package ] [ if use debian cli as base image, just delete this part]
apt purge -y xfce4 chromium-x11 xserver-xorg-core xserver-xorg-legacy rockchip-chromium-x11-utils firefox-esr x11-apps
# fix radxa-sddm-theme uninstall issue
mkdir -p /usr/share/sddm/themes/breeze
touch /usr/share/sddm/themes/breeze/Main.qml
apt autoremove -y --purge

# Update system to date
apt update
apt -y dist-upgrade --allow-downgrades

# Remove old kernel in radxa-zero3_debian_bullseye_xfce_b6.img
dpkg -l | grep -q "linux-image-5.10.160-26-rk356x" && apt purge -y linux-image-5.10.160-26-rk356x linux-headers-5.10.160-26-rk356x

## 
mkdir -p /home/radxa/SourceCode
cd /home/radxa/SourceCode

# 8812au
git clone -b v5.2.20 --depth=1 https://github.com/svpcom/rtl8812au.git
pushd rtl8812au
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# 8812eu
git clone https://github.com/libc0607/rtl88x2eu-20230815.git
pushd rtl88x2eu-20230815
git checkout 0e98ea110381d627ae4fdf7a14e38a361b197257
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# 8812cu
# 8731bu
# 8814au
# 8812bu
# MT7620

# wfb-ng
git clone -b stable --depth=1 https://github.com/svpcom/wfb-ng.git
pushd wfb-ng
./scripts/install_gs.sh wlanx
popd

# PixelPilot_rk / fpvue / gstreamer1
#  build-essential
# From JohnDGodwin
apt -y install cmake librockchip-mpp-dev libdrm-dev libcairo-dev
apt --no-install-recommends -y install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools

git clone --depth=1 https://github.com/OpenIPC/PixelPilot_rk.git
pushd PixelPilot_rk
cmake -B build
cmake --build build --target install
popd

# SBC-GS-CC
git clone --depth=1 https://github.com/zhouruixi/SBC-GS.git
pushd SBC-GS
./gs/install.sh
popd

# install useful packages
apt -y install lrzsz net-tools socat netcat

rm -rf /home/radxa/SourceCode
chown -R radxa:radxa /home/radxa

exit 0
