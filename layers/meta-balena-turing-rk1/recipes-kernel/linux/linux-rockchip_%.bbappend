FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit kernel-balena

# Add Turing RK1 kernel configuration fragments
SRC_URI:append:turing-rk1 = " \
    file://default-root.cfg \
"

# Apply UART9 console configuration to kernel
do_configure:append:turing-rk1() {
    # Merge our config fragment into the kernel config
    cat ${WORKDIR}/default-root.cfg >> ${B}/.config
    
    # Run oldconfig to process the new settings
    oe_runmake -C ${S} O=${B} olddefconfig
}
