FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

HOSTAPP_HOOKS += " \
    99-flash-bootloader \
"
