#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# clone the required layers
[ ! -d "poky" ] && git clone -b scarthgap https://git.yoctoproject.org/poky
[ ! -d "meta-openembedded" ] && git clone -b scarthgap https://git.openembedded.org/meta-openembedded
[ ! -d "meta-arm" ] && git clone -b scarthgap https://git.yoctoproject.org/meta-arm
[ ! -d "meta-rockchip" ] && git clone -b scarthgap https://github.com/radxa/meta-rockchip
[ ! -d "meta-balena" ] && git clone -b v6.0.21 https://github.com/balena-os/meta-balena
[ ! -d "balena-yocto-scripts" ] && git clone https://github.com/balena-os/balena-yocto-scripts

# set up the build environment
source poky/oe-init-build-env build

# Helper function to add layer if not already added
add_layer_if_needed() {
  local layer="$1"
  if ! bitbake-layers show-layers | grep -q "$(basename "$layer")"; then
    bitbake-layers add-layer "$layer"
  fi
}

# meta-openembedded pieces
add_layer_if_needed ../meta-openembedded/meta-oe
add_layer_if_needed ../meta-openembedded/meta-python
add_layer_if_needed ../meta-openembedded/meta-networking

# meta-arm pieces (both are required)
add_layer_if_needed ../meta-arm/meta-arm-toolchain
add_layer_if_needed ../meta-arm/meta-arm

# finally meta-rockchip
add_layer_if_needed ../meta-rockchip

# ---- create a custom layer for RK1 support ----
LAYER=../meta-turing-rk1
if [ ! -d "$LAYER" ]; then
  bitbake-layers create-layer "$LAYER"
fi
add_layer_if_needed "$LAYER"

# ---- define a new machine: turing-rk1 ----
mkdir -p "$LAYER/conf/machine"
cat > "$LAYER/conf/machine/turing-rk1.conf" <<'EOF'
require conf/machine/rock-5b.conf

# Use the RK1 device tree (we will add it to the kernel build via a patch)
KERNEL_DEVICETREE = "rockchip/rk3588-turing-rk1.dtb"
EOF

# ---- linux-rockchip must accept our new machine name ----
mkdir -p "$LAYER/recipes-kernel/linux/linux-rockchip/files"

cat > "$LAYER/recipes-kernel/linux/linux-rockchip/linux-rockchip_%.bbappend" <<'EOF'
# Allow linux-rockchip to build for our custom machine
COMPATIBLE_MACHINE:append = "|turing-rk1"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " \
  file://0001-dts-rockchip-add-turing-rk1.patch \
"
EOF

# ---- create the kernel patch by embedding the DTS/DTSI from Armbian ----
DTS_URL="https://raw.githubusercontent.com/armbian/linux-rockchip/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts"
DTSI_URL="https://raw.githubusercontent.com/armbian/linux-rockchip/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi"

TMPDTS="$(mktemp)"
TMPDTSI="$(mktemp)"
curl -fsSL "$DTS_URL"  -o "$TMPDTS" || { echo "Failed to download DTS"; exit 1; }
curl -fsSL "$DTSI_URL" -o "$TMPDTSI" || { echo "Failed to download DTSI"; exit 1; }

PATCHFILE="$LAYER/recipes-kernel/linux/linux-rockchip/files/0001-dts-rockchip-add-turing-rk1.patch"
cat > "$PATCHFILE" <<EOF
From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
Subject: [PATCH] arm64: dts: rockchip: add Turing RK1 device tree

---
 arch/arm64/boot/dts/rockchip/Makefile               | 1 +
 arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts  | $(wc -l <"$TMPDTS") +
 arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi | $(wc -l <"$TMPDTSI") +
 3 files changed, $(($(wc -l <"$TMPDTS")+$(wc -l <"$TMPDTSI")+1)) insertions(+)
 create mode 100644 arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts
 create mode 100644 arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi

diff --git a/arch/arm64/boot/dts/rockchip/Makefile b/arch/arm64/boot/dts/rockchip/Makefile
index 000000000000..111111111111 100644
--- a/arch/arm64/boot/dts/rockchip/Makefile
+++ b/arch/arm64/boot/dts/rockchip/Makefile
@@ -1,3 +1,4 @@
+dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-turing-rk1.dtb
diff --git a/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts b/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts
new file mode 100644
index 000000000000..222222222222
--- /dev/null
+++ b/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts
@@ -0,0 +1,$(wc -l <"$TMPDTS")
$(sed 's/^/+/' "$TMPDTS")
diff --git a/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi b/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi
new file mode 100644
index 000000000000..333333333333
--- /dev/null
+++ b/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi
@@ -0,0 +1,$(wc -l <"$TMPDTSI")
$(sed 's/^/+/' "$TMPDTSI")
EOF

rm -f "$TMPDTS" "$TMPDTSI"

# ---- switch MACHINE to turing-rk1 ----
sed -i '/^MACHINE[ ?]*[?:+]*=/d' conf/local.conf
echo 'MACHINE = "turing-rk1"' >> conf/local.conf

# Ensure we produce a flashable disk image
grep -q '^IMAGE_FSTYPES' conf/local.conf || echo 'IMAGE_FSTYPES += "wic wic.xz"' >> conf/local.conf

# build the image
bitbake core-image-full-cmdline

# https://github.com/armbian/linux-rockchip/blob/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts
# https://github.com/armbian/linux-rockchip/blob/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi