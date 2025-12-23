FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit resin-u-boot

UBOOT_KCONFIG_SUPPORT = "1"

# Allow patch fuzz - context lines differ slightly from U-Boot 2024.01
# but patch applies correctly (board was added in v2024.04)
ERROR_QA:remove = "patch-fuzz"
WARN_QA:append = " patch-fuzz"

# Apply Turing RK1-specific U-Boot patches from ubuntu-rockchip
# Patch 0000 adds complete board support (defconfig, DTS, Kconfig, board files, boot targets, PCIe fix)
SRC_URI:append:turing-rk1 = " \
    file://patches/0000-board-rockchip-add-Turing-RK1-RK3588.patch \
    file://uart9_console.cfg \
"

# Use turing-rk1-rk3588 defconfig (provided by patch 0000)
UBOOT_MACHINE:turing-rk1 = "turing-rk1-rk3588_defconfig"

# Merge config fragments after defconfig
do_configure:append:turing-rk1() {
    # Use U-Boot's merge_config.sh script to properly merge config fragments
    if [ -f ${WORKDIR}/uart9_console.cfg ]; then
        ${S}/scripts/kconfig/merge_config.sh -m -O ${B} ${B}/.config ${WORKDIR}/uart9_console.cfg
        # Run olddefconfig again to ensure all dependencies are resolved
        oe_runmake -C ${S} O=${B} olddefconfig
    fi
}

# BalenaOS boot partition configuration
BALENA_BOOT_PART = "4"
BALENA_DEFAULT_ROOT_PART = "5"

# RK3588 has eMMC on mmc device 0
RESIN_BOOT_DEV = "0"

# DISABLED FOR TESTING: Use meta-rockchip's bootloader generation instead
# We need rkbin-tools-native to create RK3588 bootloader images during build
# DEPENDS += "rkbin-tools-native"

# Force recompile to ensure bootloader images get deployed
# do_compile[nostamp] = "1"

# DISABLED FOR TESTING: Let meta-rockchip handle bootloader image creation
# Create RK3588 bootloader images after U-Boot compilation
# do_compile:append() {
#     # DEPLOY_DIR_IMAGE points to images/<machine>
#     # meta-rockchip's rockchip-rkbin deploys these files with simplified names
#     DDR_BLOB="${DEPLOY_DIR_IMAGE}/ddr-${SOC_FAMILY}.bin"
#     BL31_ELF="${DEPLOY_DIR_IMAGE}/bl31-${SOC_FAMILY}.elf"
#     
#     # Create idbloader.img (TPL+SPL combined with DDR blob)
#     ./tools/mkimage -n ${SOC_FAMILY} -T rksd \
#         -d "${DDR_BLOB}" \
#         ${B}/idbloader.img
#     
#     # Append BL31 to idbloader
#     cat "${BL31_ELF}" >> ${B}/idbloader.img
# 
#     # Create u-boot.img using loaderimage tool from rkbin-tools
#     loaderimage --pack --uboot ${B}/${SPL_BINARY} ${B}/u-boot.img 0x200000
# 
#     # Create trust.bin (ATF/BL31) using trust_merger from rkbin-tools
#     # Note: trust_merger expects a trust.ini file in the source directory
#     if [ -f ${S}/trust.ini ]; then
#         trust_merger --replace bl31.elf "${BL31_ELF}" ${S}/trust.ini
#         cp ${B}/trust.bin ${B}/trust.bin
#     fi
# }

# Install boot.scr to rootfs /boot for BalenaOS if needed
do_install:append() {
    if [ -f ${WORKDIR}/boot.scr ]; then
        install -D -m 644 ${WORKDIR}/boot.scr ${D}/boot/
    fi
}
