#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Store the project root directory before changing directories
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# clone the required layers
[ ! -d "poky" ] && git clone -b scarthgap https://git.yoctoproject.org/poky
[ ! -d "meta-openembedded" ] && git clone -b scarthgap https://git.openembedded.org/meta-openembedded
[ ! -d "meta-arm" ] && git clone -b scarthgap https://git.yoctoproject.org/meta-arm
[ ! -d "meta-rockchip" ] && git clone -b scarthgap https://github.com/radxa/meta-rockchip

# set up the build environment
set +u
source poky/oe-init-build-env build
set -u

# Helper function to add layer if not already added
add_layer_if_needed() {
  local layer="$1"
  local abs_layer="$(cd "$(dirname "$layer")" && pwd)/$(basename "$layer")"
  echo "Checking layer: $layer"
  if ! grep -q "^  $abs_layer" build/conf/bblayers.conf 2>/dev/null; then
    echo "Adding layer: $layer"
    bitbake-layers add-layer "$layer" || { echo "Failed to add layer: $layer"; return 1; }
  else
    echo "Layer already present: $(basename "$layer")"
  fi
}

# meta-openembedded pieces
add_layer_if_needed ../meta-openembedded/meta-oe
add_layer_if_needed ../meta-openembedded/meta-python
add_layer_if_needed ../meta-openembedded/meta-networking

# meta-arm pieces (both are required) - must be before meta-rockchip
add_layer_if_needed ../meta-arm/meta-arm-toolchain
add_layer_if_needed ../meta-arm/meta-arm

# meta-rockchip (depends on meta-arm)
add_layer_if_needed ../meta-rockchip

# ---- create a custom layer for RK1 support ----
LAYER=../meta-turing-rk1
LAYER_CHANGED=0

if [ ! -d "$LAYER" ]; then
  bitbake-layers create-layer "$LAYER"
  LAYER_CHANGED=1
fi
add_layer_if_needed "$LAYER"

# ---- define a new machine: turing-rk1 ----
mkdir -p "$LAYER/conf/machine"
MACHINE_CONF="$LAYER/conf/machine/turing-rk1.conf"
if [ ! -f "$MACHINE_CONF" ]; then
  cat > "$MACHINE_CONF" <<'EOF'
# Inherit from Rock 5B - RK1 uses same RK3588 SoC
require conf/machine/rock-5b.conf

# Use Rockchip's BSP kernel with full hardware support
PREFERRED_PROVIDER_virtual/kernel = "linux-rockchip"

# Turing RK1 specific device tree
KERNEL_DEVICETREE = "rockchip/rk3588-turing-rk1.dtb"

# Turing RK1 uses UART9 for serial console
SERIAL_CONSOLES = "115200;ttyS9"

# Set OLDEST_KERNEL to match our 5.10 kernel
OLDEST_KERNEL = "5.10"
EOF
  LAYER_CHANGED=1
fi

# Kernel recipe (linux-rockchip_6.1.bb) is maintained in the layer directly

# If layer files changed, clean the kernel to force rebuild
if [ $LAYER_CHANGED -eq 1 ]; then
  echo "Layer files changed, cleaning kernel build state..."
  bitbake -c cleansstate virtual/kernel 2>/dev/null || true
fi

# ---- switch MACHINE to turing-rk1 ----
sed -i '/^MACHINE[ ?]*[?:+]*=/d' conf/local.conf
echo 'MACHINE = "turing-rk1"' >> conf/local.conf

# Ensure we produce a flashable disk image
grep -q '^IMAGE_FSTYPES' conf/local.conf || echo 'IMAGE_FSTYPES += "wic wic.xz"' >> conf/local.conf

# Use systemd instead of sysvinit (avoids sysvinit-inittab issues)
grep -q '^INIT_MANAGER' conf/local.conf || echo 'INIT_MANAGER = "systemd"' >> conf/local.conf

# build the image
bitbake core-image-full-cmdline

# Using Armbian's linux-rockchip kernel:
# https://github.com/armbian/linux-rockchip/tree/rk-6.1-rkr5.1
# Device tree: https://github.com/armbian/linux-rockchip/blob/rk-6.1-rkr5.1/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts