FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Allow patch fuzz - context lines differ slightly from U-Boot 2024.01
# but patch applies correctly (board was added in v2024.04)
ERROR_QA:remove = "patch-fuzz"
WARN_QA:append = " patch-fuzz"

# Apply Turing RK1-specific U-Boot patches from ubuntu-rockchip
# Patch 0000 adds complete board support (defconfig, DTS, Kconfig, board files, boot targets, PCIe fix)
SRC_URI:append:turing-rk1 = " \
    file://patches/0000-board-rockchip-add-Turing-RK1-RK3588.patch \
"

# Use turing-rk1-rk3588 defconfig (provided by patch 0000)
UBOOT_MACHINE:turing-rk1 = "turing-rk1-rk3588_defconfig"
