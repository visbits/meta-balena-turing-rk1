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
- **Serial Console**: UART9 at 115200n8 (ONLY port accessible via Turing Pi chassis)
- **Target Linux**: Ubuntu 22.04, Kernel 5.15 LTS
- **IMPORTANT**: RK1 modules in Turing Pi chassis only expose UART9 - no access to UART2

### DDR Binary Customization for UART9
The DDR initialization binary must be customized to output on UART9:

**Source**: Rockchip's official rkbin repository:
```
https://github.com/rockchip-linux/rkbin/tree/master/bin/rk35
File: rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
```

**Customization**: Modified using `ddrbin_tool.py` with parameters:
```
start tag=0x12345678
uart id=9
uart iomux=0
uart baudrate=115200
end
```

**Result**: Produces `rk3588_ddr_lp4_2112MHz_lp5_2400MHz_uart9_115200_v1.16.bin`
- Enables DDR initialization messages on UART9
- Leaves UART9 initialized for U-Boot SPL and proper
- Without this, DDR messages appear on UART2 (inaccessible in Turing Pi 2 chassis)

**Critical**: This customization is required for complete boot chain console output on UART9.

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
├── recipes-bsp/
│   └── u-boot/
│       ├── u-boot_%.bbappend        # U-Boot configuration for UART9
│       └── files/
│           └── turing-rk1-uart9.cfg # UART9 @ 115200 configuration
└── recipes-kernel/
    └── linux/
        └── linux-rockchip_5.10.bb   # Rockchip BSP kernel with RK1 device tree
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

## Build Process

### Using Makefile (Recommended)
```bash
make image        # Clean build of complete balena image
make copy         # Copy image to remote server
make copyflash    # Copy and flash to device
```

The `make image` target runs `docker-build.sh` which handles the complete containerized build.

### Step-by-Step Workflow (docker-build.sh)
1. **Clone layers**: Fetch all Yocto layers (scarthgap branch)
2. **Build Docker image**: Creates Ubuntu 22.04 container with Yocto dependencies
3. **Initialize build**: Docker container sources `poky/oe-init-build-env build`
4. **Add layers**: Register all meta-layers with bitbake
5. **Create custom layer**: Use `bitbake-layers create-layer meta-turing-rk1`
6. **Define machine**: Create `turing-rk1.conf` inheriting from `rk3588.inc`
7. **Kernel modification**: 
   - Create bbappend for linux-yocto
   - Copy DTS/DTSI files from Armbian kernel
   - Copy Rockchip-specific dt-bindings headers
   - Add Makefile entry for new DTB
8. **Configure build**: Set `MACHINE = "turing-rk1"` in local.conf
9. **Build image**: Run `./docker-build.sh` (runs bitbake inside container)
10. **Output**: WIC disk image in `build/tmp/deploy/images/turing-rk1/`

### Important: Always Use Docker Container
**All builds MUST run inside the Docker container using `./docker-build.sh`**. Do NOT run bitbake commands directly on the host system. The Docker container provides:
- Correct path mappings (`/workdir` instead of host paths)
- Consistent Ubuntu 22.04 environment
- All required Yocto build dependencies
- Proper user permissions and locale settings

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
- **Clean builds**: Use `./docker-build.sh` after recipe changes, or manually clean inside container: `bitbake -c cleanall linux-yocto`
- **Recipe debugging**: Inside container: `bitbake -e linux-yocto | grep DEVICETREE` to check variables
- **Machine changes**: Always rebuild after changing machine configuration
- **Path mappings**: All build paths inside container use `/workdir` prefix
- **Never run bitbake on host**: Host paths don't match container paths in bblayers.conf

### Common Build Commands
**Always run these inside Docker container via `./docker-build.sh`**

The docker-build.sh script handles:
- Building the yocto-rk1-builder Docker image
- Mounting the workspace to `/workdir` inside container
- Running as builder user (uid 1000) for proper permissions
- Initializing the Yocto build environment
- Adding all required layers
- Building core-image-full-cmdline for turing-rk1

**CRITICAL: Build Process Management**
- Yocto builds can take 30+ minutes to hours depending on what changed
- **NEVER interrupt a running build** by running commands in the same terminal
- **ALWAYS wait for builds to complete** before running investigation commands
- **Use a separate terminal** for checking files, grepping, or other operations while build runs
- Check if build is running with `ps aux | grep bitbake` before using that terminal
- Background builds with `make image &` if you need the terminal, but prefer dedicated terminals

For manual bitbake commands inside the container:
```bash
# Enter the Docker container (from project root)
docker run -it --rm -v $(pwd):/workdir yocto-rk1-builder bash

# Inside container - source build environment
source poky/oe-init-build-env build

# Then run bitbake commands
bitbake core-image-full-cmdline          # Build full image
bitbake -c menuconfig linux-yocto        # Configure kernel
bitbake -c devshell linux-yocto          # Drop into build shell
bitbake -c cleanall linux-yocto          # Clean kernel build
bitbake -s | grep linux                  # Check kernel version
bitbake world --runonly=fetch            # Pre-fetch all sources

# When finished, return to project root
cd /workdir
```

**IMPORTANT**: Always return to project root (`cd ~/rockchip-rk3588-rk1-yocto-balena` or `cd /workdir` in container) after running commands in subdirectories to maintain consistent working directory context.

### Image Flashing
Output files in `build/tmp/deploy/images/turing-rk1/`:
- `core-image-full-cmdline-turing-rk1.wic.xz` - Compressed disk image
- Flash to SD/eMMC: `xzcat image.wic.xz | sudo dd of=/dev/sdX bs=4M status=progress`

**NOTE**: After working in subdirectories like `/tmp` or `build/`, always return to project root with `cd ~/rockchip-rk3588-rk1-yocto-balena`

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

### Architecture Overview
This build includes meta-balena for:
- **Container runtime**: Docker-compatible engine (Balena Engine)
- **OTA updates**: Over-the-air system updates with A/B partition switching
- **Device management**: Fleet management capabilities
- **Application deployment**: Container-based apps with orchestration

### BalenaOS Image Structure (7 partitions, 1.31 GiB total)

| Partition | Name | Size | Type | Purpose |
|-----------|------|------|------|---------|
| 1 | idbloader | 4MB | raw | RK3588 bootloader stage 1 (DDR init + SPL) |
| 2 | uboot | 8MB | raw | U-Boot FIT image with ATF BL31 |
| 3 | resin-boot | 80MB | FAT16 | Boot partition (kernel, DTB, extlinux.conf) |
| 4 | resin-rootA | 500MB | ext4 | **Active OS partition** (overlay2 layers) |
| 5 | resin-rootB | 500MB | ext4 | **Inactive OS partition** (for A/B updates) |
| 6 | resin-state | 20MB | ext4 | Persistent state data |
| 7 | resin-data | 203MB+ | ext4 | Docker storage & application data |

### Root Filesystem Architecture: Docker Overlay2

**CRITICAL**: BalenaOS does NOT use a traditional root filesystem structure!

Instead, it uses **Docker overlay2 layers** for the OS:

```
resin-rootA/ (or resin-rootB)
├── balena/
│   ├── overlay2/                      # Docker overlay filesystem layers
│   │   └── <hash>/diff/               # ← ACTUAL OS ROOT FILESYSTEM HERE
│   │       ├── bin/                   # System binaries
│   │       ├── sbin/                  # System admin binaries  
│   │       ├── usr/                   # User programs
│   │       ├── etc/                   # System configuration
│   │       ├── lib/                   # System libraries
│   │       └── resin-boot/            # Boot mount point
│   └── volumes/                       # Docker volumes
│       └── <hash>/_data/
│           └── init                   # Init binary (9.8MB)
├── hostapps/                          # Host application layers
│   └── <hash>/
│       └── boot -> ../../balena/volumes/.../
└── current -> hostapps/<hash>         # Symlink to active OS layer
```

**Key points:**
- OS files are in `/balena/overlay2/<hash>/diff/` NOT in traditional `/bin`, `/usr`, etc.
- The `init` binary (9.8MB) orchestrates mounting overlay2 layers at boot
- This enables atomic A/B updates with instant rollback capability
- rootA is active, rootB is empty (ready for next update)
- Both partitions work identically - switching is just changing which one boots

### CRITICAL: Boot File Deployment Mechanism

**Balena uses BALENA_BOOT_PARTITION_FILES, NOT rootfs packages for boot files!**

Key points:
1. **kernel-balena-noimage.bbclass** explicitly EXCLUDES all kernel-image packages via `PACKAGE_EXCLUDE`
2. Boot files (kernel, DTB, extlinux.conf) are deployed **at image creation time** during `do_image_balenaos-img`
3. Files go directly from `DEPLOY_DIR_IMAGE` to boot partition, bypassing rootfs
4. This is by design - never try to install kernel via IMAGE_INSTALL packages

**Correct approach** (in balena-image.inc):
```bitbake
BALENA_BOOT_PARTITION_FILES:append = " \
    idbloader.img:/ \
    u-boot.itb:/ \
    fitImage:/boot/fitImage \
    rk3588-turing-rk1.dtb:/boot/rk3588-turing-rk1.dtb \
    extlinux.conf:/boot/extlinux/extlinux.conf \
"
```

**See BALENA-KERNEL-DEPLOYMENT.md for complete details on why package-based approaches fail.**

### Boot Partition Contents (resin-boot)
```
/
├── idbloader.img              # Bootloader (for OTA)
├── u-boot.itb                 # U-Boot (for OTA)
├── config.json                # Device config
├── device-type.json           # Device metadata
├── os-release                 # OS version
└── boot/
    ├── fitImage               # Kernel (~25MB)
    ├── rk3588-turing-rk1.dtb  # Device tree
    └── extlinux/
        └── extlinux.conf      # Boot config
```

### A/B Update System
- **Active**: resin-rootA contains current OS in overlay2 layer
- **Inactive**: resin-rootB empty, ready for next update
- **Update**: Downloads to inactive partition, switches on reboot
- **Rollback**: If boot fails, automatically switches back to previous partition
- **Atomic**: Updates are all-or-nothing, no partial states

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

## CRITICAL SAFETY RESTRICTIONS

### FORBIDDEN OPERATIONS - NEVER EXECUTE THESE COMMANDS:

**⚠️ ABSOLUTELY PROHIBITED ⚠️**
- **NEVER** run `dd` commands that write to any device or partition (`of=/dev/*`)
- **NEVER** run `dd` commands that write to existing files without explicit user confirmation
- **NEVER** execute destructive commands on remote systems via SSH
- **NEVER** overwrite existing storage devices, partitions, or mounted filesystems
- **NEVER** run commands that could cause data loss without explicit user permission
- **NEVER** use `sudo` for anything except mounting/unmounting operations
- **NEVER** use `sudo rm`, `sudo dd`, or any other privileged destructive commands

**Safe alternatives:**
- For image creation: Only write to new files or explicitly user-specified targets
- For remote operations: Only read operations or explicit user-confirmed write targets
- For testing: Use loop devices, temporary files, or dedicated test partitions
- For build cleanup: Use regular user permissions (Yocto builds run as user, not root)
- Always ask for explicit confirmation before ANY destructive operation

**Sudo usage policy:**
- **ONLY ALLOWED**: `sudo mount`, `sudo umount`, `sudo losetup` for inspecting images
- **FORBIDDEN**: `sudo rm`, `sudo dd`, `sudo chmod -R`, or any other privileged operations
- **Rationale**: Yocto/Balena builds should never require root - if sudo seems needed, something is wrong

### Examples of FORBIDDEN commands:
```bash
# NEVER run these:
dd if=image.img of=/dev/mmcblk0        # Overwrites storage device
dd if=image.img of=/dev/sda            # Destroys disk contents
ssh host 'dd if=X of=/dev/Y'          # Remote destructive operation
rm -rf / or similar                    # Filesystem destruction
sudo rm -rf build/                     # Unnecessary privilege escalation
sudo dd if=X of=Y                      # Privileged destructive operation
```

**When in doubt, ASK FIRST. Data safety is paramount.**

---

## Quick Start for Copilot

When assisting with this project:

### Core Understanding
1. **Project Type**: Yocto Linux build for embedded ARM64 hardware with BalenaOS
2. **Key Architecture**: BalenaOS uses Docker overlay2 layers for root filesystem (NOT traditional rootfs)
3. **Boot Files**: Deployed via BALENA_BOOT_PARTITION_FILES mechanism (NOT packages)
4. **Build Command**: `make image` for clean builds

### Key Files & Locations
- **Machine Config**: `layers/meta-balena-turing-rk1/conf/machine/turing-rk1.conf`
- **Image Config**: `layers/meta-balena-turing-rk1/recipes-core/images/balena-image.inc`
- **U-Boot**: `layers/meta-balena-turing-rk1/recipes-bsp/u-boot/`
- **Kernel**: `layers/meta-balena-turing-rk1/recipes-kernel/linux/`
- **Build Output**: `build/tmp/deploy/images/turing-rk1/`
- **Documentation**: `BALENA-KERNEL-DEPLOYMENT.md` (boot file deployment details)

### Important Concepts
1. **Device Tree**: Primary hardware configuration mechanism (from Armbian linux-rockchip)
2. **UART9**: ONLY accessible serial console (not UART2!) at 115200n8
   - DDR blob must be customized with ddrbin_tool.py to output on UART9
   - Without customization, DDR init uses UART2 (inaccessible)
3. **Overlay2**: OS stored as Docker overlay layer in `/balena/overlay2/<hash>/diff/`
4. **A/B Updates**: rootA (active) and rootB (inactive) for atomic updates
5. **Boot Partition**: Contains kernel, DTB, extlinux.conf deployed via BALENA_BOOT_PARTITION_FILES

### Image Verification
When checking if build is complete:
- **Boot partition** (p3): Should have fitImage, DTB, extlinux.conf in /boot/
- **rootA** (p4): Should have /balena/overlay2/<hash>/diff/ with OS files
- **rootB** (p5): Empty (ready for updates)
- **resin-data** (p7): Docker storage initialized

### Common Tasks
- **Build**: `make image` (NOT direct bitbake commands)
- **Check Partition**: Mount and inspect overlay2 layers for OS files
- **Kernel Updates**: Modify kernel bbappend, rebuild deploys to boot partition automatically
- **U-Boot Changes**: Must preserve UART9 console configuration

### CRITICAL Restrictions
- **NEVER** run destructive dd commands without explicit user confirmation
- **ALWAYS** preserve UART9 console configuration (user directive: "DO NOT TOUCH")
- **NEVER** try to install kernel via IMAGE_INSTALL (use BALENA_BOOT_PARTITION_FILES)
- **PRIORITIZE SAFETY**: Data safety is paramount - ask before destructive operations
