FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add Turing RK1 support to rockchip-rkbin
# Uses RK1-specific blobs from ubuntu-rockchip that include UART9 support

COMPATIBLE_MACHINE:append = "|turing-rk1"

# RK1-specific blob versions (from ubuntu-rockchip)
DDRBIN_VERS:turing-rk1 = "v1.16"
DDRBIN_FILE:turing-rk1 = "rk3588_ddr_lp4_2112MHz_lp5_2400MHz_uart9_115200_v1.16.bin"

# Deploy RK1-specific blobs
do_deploy:turing-rk1() {
    # Prebuilt TF-A (Trusted Firmware-A / BL31) - RK1 version
    install -m 644 ${WORKDIR}/rk3588_bl31_v1.45.elf ${DEPLOYDIR}/bl31-rk3588.elf
    
    # Prebuilt U-Boot TPL (DDR init) - RK1 version with UART9 @ 115200
    install -m 644 ${WORKDIR}/${DDRBIN_FILE} ${DEPLOYDIR}/ddr-rk3588.bin
}

# Add RK1 blob files to SRC_URI
SRC_URI:append:turing-rk1 = " \
    file://rk3588_bl31_v1.45.elf \
    file://rk3588_ddr_lp4_2112MHz_lp5_2400MHz_uart9_115200_v1.16.bin \
    file://rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin \
"
