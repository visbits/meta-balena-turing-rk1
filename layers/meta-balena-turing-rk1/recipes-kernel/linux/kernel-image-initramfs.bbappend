# RK3588 uses U-Boot and loads kernel/initramfs separately
# We don't need a bundled kernel+initramfs image
# Similar to Jetson Nano which also uses U-Boot

# Override the install to do nothing since we don't have a bundled fitImage
do_install() {
    # Nothing to install - kernel and initramfs are loaded separately by U-Boot
    :
}
