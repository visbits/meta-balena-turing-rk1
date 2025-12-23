IMAGE_FSTYPES += "balenaos-img"

PARTITION_TABLE_TYPE = "gpt"

# Device specific space before first partition (for bootloader)
DEVICE_SPECIFIC_SPACE = "40960"

# Increase boot and rootfs partition sizes
IMAGE_ROOTFS_SIZE = "512000"
BALENA_BOOT_SIZE = "80960"

# Remove kernel packaging from rootfs - we deploy via BALENA_BOOT_PARTITION_FILES instead
# packagegroup-core-boot pulls in kernel-image which creates fitImage in rootfs /boot
# Balena deploys boot files directly to boot partition at image creation time, not via rootfs packages
IMAGE_INSTALL:remove = "kernel-image-initramfs packagegroup-core-boot"

# RK3588 bootloader variables
# Modern RK3588 uses idbloader.img + u-boot.itb (FIT image with BL31 embedded)
# No separate trust.bin - BL31 is bundled into u-boot.itb
RK_IDBLOADER = "idbloader.img"
RK_UBOOT_ITB = "u-boot.itb"

# Create device-specific partitions for bootloader components
device_specific_configuration() {
    # Create partitions for RK3588 bootloader components
    # idbloader at sector 64 (32KB offset)
    parted -s ${BALENA_RAW_IMG} unit s mkpart idbloader 64 8063
    # u-boot.itb at sector 16384 (8MB offset)
    parted -s ${BALENA_RAW_IMG} unit s mkpart uboot 16384 32767
}

# Flash bootloader components to raw image
IMAGE_CMD:balenaos-img:append() {
    # Flash RK3588 bootloader components to raw image
    # These are the offsets used by Rockchip RK3588 boot ROM
    dd if=${DEPLOY_DIR_IMAGE}/${RK_IDBLOADER} of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/${RK_UBOOT_ITB} of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384
}

# Deploy bootloader and kernel components to boot partition using balena mechanism
# This is how balena-jetson does it - files are deployed at image creation time
# The kernel build automatically creates fitImage and DTB in DEPLOY_DIR_IMAGE
BALENA_BOOT_PARTITION_FILES:append = " \
    idbloader.img:/ \
    u-boot.itb:/ \
    fitImage:/boot/fitImage \
    rk3588-turing-rk1.dtb:/boot/rk3588-turing-rk1.dtb \
    extlinux.conf:/boot/extlinux/extlinux.conf \
"
