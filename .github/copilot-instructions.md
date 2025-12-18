# GitHub Copilot Instructions for Turing RK1 Yocto Build

## Project Overview
This project builds a custom Yocto/OpenEmbedded Linux distribution for the **Turing RK1** compute module, featuring the Rockchip RK3588 SoC. The build creates a flashable disk image with full hardware support via device tree integration.

## Hardware: Turing RK1 Specifications
- **SoC**: Rockchip RK3588 (8-core ARM64)
- **RAM**: 16GB or 32GB configurations
- **NPU**: 6 TOPS Neural Processing Unit (TensorFlow, PyTorch, Caffe)
- **Video Encoding**: 2K@60fps
- **TDP**: 7W
- **PCIe**: Gen 3, 4× lanes
- **Compatibility**: NVIDIA Jetson pin layout
- **Serial Console**: UART9 at 115200n8
- **Target Linux**: Ubuntu 22.04, Kernel 5.15 LTS

## Build Architecture

### Yocto Layers (Scarthgap Release)
1. **poky**: Core Yocto build system
2. **meta-openembedded**: meta-oe, meta-python, meta-networking
3. **meta-arm**: ARM toolchain and architecture support
4. **meta-rockchip**: Rockchip SoC BSP (Board Support Package)
5. **meta-balena**: Container-based OS support
6. **meta-turing-rk1** (custom): Turing RK1-specific machine and device tree

### Custom Layer Structure: meta-turing-rk1
```
meta-turing-rk1/
├── conf/
│   └── machine/
│       └── turing-rk1.conf          # Machine definition, inherits rock-5b.conf
└── recipes-kernel/
    └── linux/
        ├── linux-yocto_%.bbappend   # Kernel recipe extension
        └── files/
            └── 0001-dts-rockchip-add-turing-rk1.patch  # Device tree patch
```

## Device Tree Integration

### Key Device Tree Files
- **rk3588-turing-rk1.dts** (18 lines): Main device tree
  - Model: "Turing Machines RK1"
  - Compatible: "turing,rk1", "rockchip,rk3588"
  - Stdout: serial9:115200n8
  
- **rk3588-turing-rk1.dtsi** (764 lines): Hardware configuration
  - Display subsystem (HDMI, VOP, DSI)
  - USB 2.0/3.0 PHYs and controllers
  - PCIe Gen 3 controllers
  - GMAC0/1 ethernet
  - Power management (regulators, thermal)
  - GPIO, I2C, SPI, UART interfaces
  - NPU (Neural Processing Unit)
  - Audio (codecs, SPDIF)

### Device Tree Source
Device trees are sourced from **Armbian's linux-rockchip** kernel tree (branch: `rk-5.10-rkr6`):
- https://github.com/armbian/linux-rockchip/blob/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts
- https://github.com/armbian/linux-rockchip/blob/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi

## Build Process (build.sh)

### Step-by-Step Workflow
1. **Clone layers**: Fetch all Yocto layers (scarthgap branch)
2. **Initialize build**: Source `poky/oe-init-build-env build`
3. **Add layers**: Register all meta-layers with bitbake
4. **Create custom layer**: Use `bitbake-layers create-layer meta-turing-rk1`
5. **Define machine**: Create `turing-rk1.conf` inheriting from `rock-5b.conf`
6. **Kernel modification**: 
   - Create bbappend for linux-yocto
   - Download DTS/DTSI from Armbian GitHub
   - Generate kernel patch embedding device trees
   - Add Makefile entry for new DTB
7. **Configure build**: Set `MACHINE = "turing-rk1"` in local.conf
8. **Build image**: Run `bitbake core-image-full-cmdline`
9. **Output**: WIC disk image in `build/tmp/deploy/images/turing-rk1/`

### Machine Configuration
```bash
# turing-rk1.conf inherits most settings from rock-5b
require conf/machine/rock-5b.conf
KERNEL_DEVICETREE = "rockchip/rk3588-turing-rk1.dtb"
```

### Kernel Patch Strategy
The patch adds:
- Makefile entry: `dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-turing-rk1.dtb`
- New file: `arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dts`
- New file: `arch/arm64/boot/dts/rockchip/rk3588-turing-rk1.dtsi`

## Development Guidelines

### When Working with Device Trees
- **DTS changes**: Modify the patch generation in build.sh or manually edit the patch file
- **Testing**: Device tree issues manifest as missing/non-functional hardware
- **Debugging**: Check kernel log (`dmesg`) for device probe failures
- **References**: Compare with rock-5b device tree for similar RK3588 hardware

### When Modifying the Build
- **Layer priority**: meta-turing-rk1 should have higher priority than meta-rockchip
- **Clean builds**: Use `bitbake -c cleanall linux-yocto` when kernel changes don't apply
- **Recipe debugging**: Use `bitbake -e linux-yocto | grep DEVICETREE` to check variables
- **Machine changes**: Always rebuild after changing machine configuration

### Common BitBake Commands
```bash
bitbake core-image-full-cmdline          # Build full image
bitbake -c menuconfig linux-yocto        # Configure kernel
bitbake -c devshell linux-yocto          # Drop into build shell
bitbake -s | grep linux                  # Check kernel version
bitbake world --runonly=fetch            # Pre-fetch all sources
```

### Image Flashing
Output files in `build/tmp/deploy/images/turing-rk1/`:
- `core-image-full-cmdline-turing-rk1.wic.xz` - Compressed disk image
- Flash to SD/eMMC: `xzcat image.wic.xz | sudo dd of=/dev/sdX bs=4M status=progress`

## Key Dependencies & Compatibility

### Base System
- **Inherits from**: rock-5b machine configuration
- **Bootloader**: U-Boot (from meta-rockchip)
- **Kernel**: linux-yocto with RK3588 support
- **init system**: systemd (typical for full-cmdline)

### Hardware Enablement Priority
1. **Critical**: Serial console (UART9), eMMC/SD, basic USB
2. **Important**: Ethernet (GMAC), PCIe, display (HDMI)
3. **Enhanced**: NPU, video encode/decode, audio
4. **Optional**: All GPIO-based peripherals

### Known Limitations
- Device tree is from kernel 5.10 (Armbian), may need updates for newer kernels
- Some RK3588 features may require proprietary blobs (especially video codecs)
- NPU requires Rockchip's RKNN toolkit and libraries

## Balena OS Integration
This build includes meta-balena for:
- **Container runtime**: Docker-compatible engine
- **OTA updates**: Over-the-air system updates
- **Device management**: Fleet management capabilities
- **Application deployment**: Container-based apps

Refer to balena-yocto-scripts for Balena-specific build modifications.

## References & Documentation
- **Turing RK1 Product**: https://turingpi.com/product/turing-rk1/
- **Turing RK1 Docs**: https://docs.turingpi.com/docs/turing-rk1-specs-and-io-ports
- **Device Trees**: https://github.com/armbian/linux-rockchip/tree/rk-5.10-rkr6/arch/arm64/boot/dts/rockchip
- **meta-rockchip**: https://github.com/radxa/meta-rockchip
- **Yocto Scarthgap**: https://docs.yoctoproject.org/4.2/
- **meta-balena**: https://github.com/balena-os/meta-balena

## Troubleshooting Tips

### Build Failures
- **DTS syntax errors**: Validate with `dtc -I dts -O dtb file.dts`
- **Patch doesn't apply**: Check kernel version compatibility, may need patch context adjustment
- **Missing dependencies**: Ensure all layers are at scarthgap branch

### Runtime Issues
- **No boot**: Check U-Boot, ensure UART9 console connection
- **Missing hardware**: Verify device tree node status (should be "okay")
- **Network issues**: Check GMAC configuration and PHY initialization

### Getting Help
- Check Yocto build logs: `build/tmp/work/turing_rk1-poky-linux/linux-yocto/*/temp/log.do_*`
- Compare with rock-5b configuration for similar RK3588 board
- Reference Armbian kernel implementation for hardware enablement

---

## Quick Start for Copilot
When assisting with this project:
1. Understand this is a **Yocto Linux build** for embedded ARM64 hardware
2. Key files: `build.sh` (build script), `meta-turing-rk1/` (custom layer)
3. Device tree is the primary hardware configuration mechanism
4. Build outputs go to `build/tmp/deploy/images/turing-rk1/`
5. Always consider kernel version compatibility with device tree sources
