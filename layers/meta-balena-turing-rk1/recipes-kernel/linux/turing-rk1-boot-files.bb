# Recipe to install kernel fitImage and device trees to rootfs /boot
# Similar to balena-jetson's jetson-dtbs.bb recipe
# This is how balena installs kernel to rootfs without kernel-image package

SUMMARY = "Turing RK1 boot files (kernel + device trees)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Depend on kernel deployment
DEPENDS = "virtual/kernel"

# This recipe provides kernel and device tree files to rootfs
PROVIDES = "turing-rk1-boot-files"

inherit deploy

do_install() {
    install -d ${D}/boot
    install -d ${D}/boot/extlinux
    
    # Install kernel fitImage to /boot where extlinux expects it
    if [ -f ${DEPLOY_DIR_IMAGE}/fitImage-${MACHINE}.bin ]; then
        install -m 0644 ${DEPLOY_DIR_IMAGE}/fitImage-${MACHINE}.bin ${D}/boot/fitImage
    fi
    
    # Install device tree
    if [ -f ${DEPLOY_DIR_IMAGE}/rk3588-turing-rk1.dtb ]; then
        install -m 0644 ${DEPLOY_DIR_IMAGE}/rk3588-turing-rk1.dtb ${D}/boot/rk3588-turing-rk1.dtb
    fi
    
    # Install extlinux.conf if kernel provides it
    if [ -f ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf ]; then
        install -m 0644 ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf ${D}/boot/extlinux/extlinux.conf
    fi
}

FILES:${PN} = "/boot/fitImage /boot/*.dtb /boot/extlinux /boot/extlinux/extlinux.conf"

# Ensure kernel is deployed before we try to install it
do_install[depends] += "virtual/kernel:do_deploy"

# Don't rebuild if kernel hasn't changed
do_install[nostamp] = "1"
