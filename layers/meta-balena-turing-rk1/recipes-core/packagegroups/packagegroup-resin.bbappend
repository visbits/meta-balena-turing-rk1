# Rockchip boots from U-Boot, not a bundled initramfs kernel
# Remove kernel-image-initramfs like Jetson does
RDEPENDS:remove = "kernel-image-initramfs"
