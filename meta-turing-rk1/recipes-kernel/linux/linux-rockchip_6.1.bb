# Rockchip 6.1 BSP kernel with full RK3588 hardware support
# Based on Armbian's linux-rockchip fork
# Copyright (c) 2025, Turing Machines
# Released under the MIT license

inherit kernel

DESCRIPTION = "Rockchip 6.1 BSP Linux Kernel with RK3588 support"
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

LINUX_VERSION = "6.1.115"
LINUX_VERSION_EXTENSION = "-rockchip"

PV = "${LINUX_VERSION}+git${SRCPV}"

# Armbian's rockchip kernel with RK3588 Turing RK1 support
SRCREV = "41da3e69e16b9de57eca897215e8b0adc6efdc8b"
SRC_URI = "git://github.com/armbian/linux-rockchip.git;protocol=https;branch=rk-6.1-rkr5.1 \
    file://default-root.cfg \
"

S = "${WORKDIR}/git"

COMPATIBLE_MACHINE = "turing-rk1"

# RK1 device tree (included in Armbian kernel source)
KERNEL_DEVICETREE = "rockchip/rk3588-turing-rk1.dtb"

# Build dependencies
DEPENDS += "openssl-native util-linux-native bc-native bison-native flex-native"

# Use Rockchip's default defconfig
KBUILD_DEFCONFIG = "rockchip_linux_defconfig"

# Ensure the defconfig is used
do_configure:prepend() {
    if [ -f ${S}/arch/${ARCH}/configs/${KBUILD_DEFCONFIG} ]; then
        cp ${S}/arch/${ARCH}/configs/${KBUILD_DEFCONFIG} ${B}/.config
    else
        bbfatal "Defconfig ${KBUILD_DEFCONFIG} not found in ${S}/arch/${ARCH}/configs/"
    fi
}
