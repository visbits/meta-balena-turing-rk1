# Turing RK1 BalenaOS Build
Token: BInF5eUnCrNFJSyyseH5pPqTimlmeDKU
Custom BalenaOS distribution for the **Turing RK1** (Rockchip RK3588) compute module, built with Yocto/OpenEmbedded.

## Hardware Specifications

- **SoC**: Rockchip RK3588 (8-core ARM64: 4×Cortex-A76 + 4×Cortex-A55)
- **RAM**: 16GB or 32GB LPDDR4/LPDDR5
- **NPU**: 6 TOPS Neural Processing Unit
- **Video**: H.264/H.265 encode 2K@60fps, decode 8K@30fps
- **PCIe**: Gen 3, 4× lanes
- **Network**: Dual 2.5GbE
- **Serial Console**: **UART9 @ 115200n8** (ONLY port accessible via Turing Pi 2 chassis)
- **TDP**: 7W typical, 15W peak

## Quick Start

### Build Image
```bash
make image      # Clean build of complete BalenaOS image
make copy       # Copy image to remote server (for flashing)
make copyflash  # Copy and flash to device
```

### Flash to Device
```bash
# Decompress and write to eMMC/SD card
xzcat build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img | \
  sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

## BalenaOS Image Layout

**Total Size**: 1.31 GiB (expandable on first boot)

### Partition Structure (7 partitions):

| # | Name | Size | Type | Purpose |
|---|------|------|------|---------|
| 1 | idbloader | 4MB | raw | RK3588 bootloader stage 1 (DDR init + SPL) |
| 2 | uboot | 8MB | raw | U-Boot FIT image with ATF BL31 |
| 3 | resin-boot | 80MB | FAT16 | Boot partition (kernel, DTB, config) |
| 4 | resin-rootA | 500MB | ext4 | OS partition A (active) |
| 5 | resin-rootB | 500MB | ext4 | OS partition B (for A/B updates) |
| 6 | resin-state | 20MB | ext4 | Persistent state data |
| 7 | resin-data | 203MB+ | ext4 | Docker storage & application data |

### Partition Details

#### Partition 3: resin-boot (Boot Partition)
Contains bootloader and kernel files deployed via `BALENA_BOOT_PARTITION_FILES`:
```
/
├── idbloader.img              # Bootloader copy (for OTA updates)
├── u-boot.itb                 # U-Boot copy (for OTA updates)
├── config.json                # BalenaOS device configuration
├── device-type.json           # Device type metadata
├── os-release                 # OS version information
└── boot/
    ├── fitImage               # Kernel FIT image (~25MB)
    ├── rk3588-turing-rk1.dtb  # Device tree blob
    └── extlinux/
        └── extlinux.conf      # U-Boot boot configuration
```

#### Partitions 4 & 5: resin-rootA/B (OS Partitions)
BalenaOS uses **Docker overlay2 architecture** for the root filesystem:

```
resin-rootA/
├── balena/
│   ├── overlay2/              # Docker overlay filesystem layers
│   │   └── <hash>/diff/       # Actual OS root filesystem
│   │       ├── bin/           # System binaries
│   │       ├── sbin/          # System admin binaries
│   │       ├── usr/           # User programs
│   │       ├── etc/           # System configuration
│   │       └── lib/           # System libraries
│   └── volumes/               # Docker volumes
│       └── <hash>/_data/
│           └── init           # Init binary (9.8MB)
├── hostapps/                  # Host application layers
│   └── <hash>/
│       └── boot -> ../../balena/volumes/.../
└── current -> hostapps/<hash> # Symlink to active OS
```

**Key Architecture Points**:
- OS stored as Docker overlay2 layer, not traditional rootfs
- Enables atomic A/B updates with rollback capability
- `init` binary orchestrates overlay mount at boot
- Full Linux system in `/balena/overlay2/<hash>/diff/`

#### Partition 7: resin-data (Docker Storage)
Application containers and persistent data:
```
resin-data/
├── docker/                    # Docker engine data
│   ├── overlay2/              # Container layers
│   ├── volumes/               # Container volumes
│   ├── containers/            # Container metadata
│   └── image/                 # Image metadata
└── resin-data/                # BalenaOS persistent data
```

## Boot Process

1. **RK3588 Boot ROM** → Loads `idbloader.img` from sector 64 (32KB offset)
2. **DDR Init + SPL** → Initializes LPDDR4/5 and loads U-Boot
3. **U-Boot** → Loads from sector 16384 (8MB offset), console on UART9
4. **Extlinux** → U-Boot reads `/boot/extlinux/extlinux.conf` from boot partition
5. **Kernel** → Loads `fitImage` from boot partition with device tree
6. **Init** → BalenaOS init mounts overlay2 layers and starts systemd
7. **Balena Engine** → Container runtime starts for application deployment

**Console Output**: Available on UART9 (115200n8) throughout entire boot chain

## Build Architecture

### Yocto Project
- **Release**: Scarthgap (5.0)
- **Target**: aarch64 (ARM64)
- **Kernel**: linux-rockchip 6.1.118 (from Armbian)
- **Bootloader**: U-Boot 2024.01 with Turing RK1 patches

### Layers
1. **poky** - Core Yocto build system
2. **meta-openembedded** - Additional recipes (networking, Python)
3. **meta-arm** - ARM toolchain and architecture support
4. **meta-rockchip** - Rockchip SoC BSP (Board Support Package)
5. **meta-balena** - BalenaOS framework and container runtime
6. **meta-balena-turing-rk1** - Turing RK1 specific configuration

### Custom Layer: meta-balena-turing-rk1

```
layers/meta-balena-turing-rk1/
├── conf/
│   └── machine/
│       └── turing-rk1.conf           # Machine definition
├── recipes-bsp/
│   └── u-boot/
│       ├── u-boot_%.bbappend         # U-Boot UART9 console config
│       └── files/
│           ├── patches/
│           │   └── 0000-board-rockchip-add-Turing-RK1-RK3588.patch
│           ├── uart9_console.cfg     # Debug UART on UART9
│           └── balenaos_bootcommand.cfg
├── recipes-kernel/
│   └── linux/
│       ├── linux-rockchip_%.bbappend # Kernel configuration
│       └── files/
│           └── default-root.cfg      # Console on ttyS9
└── recipes-core/
    └── images/
        └── balena-image.inc          # BalenaOS image configuration
```

## Key Configuration

### UART9 Console (CRITICAL)
Turing Pi 2 chassis only exposes UART9 (not UART2):
- **U-Boot Debug UART**: 0xfeb90000 @ 24MHz
- **Kernel Console**: `console=ttyS9,115200n8 earlycon`
- **BalenaOS**: `OS_DEVELOPMENT=1` for console output
- **DDR Blob**: Custom `rk3588_ddr_lp4_2112MHz_lp5_2400MHz_uart9_115200_v1.16.bin`

#### DDR Binary Customization
The DDR initialization binary is customized to output on UART9:

**Source**: Rockchip's official rkbin repository:
```
https://github.com/rockchip-linux/rkbin/tree/master/bin/rk35
```

**Customization**: Modified with `ddrbin_tool.py` using these parameters:
```
start tag=0x12345678
uart id=9
uart iomux=0
uart baudrate=115200
end
```

This produces the `_uart9_115200_` variant filename suffix, enabling DDR initialization messages on UART9 and leaving it initialized for U-Boot to continue using. Without this customization, DDR init messages would appear on UART2 (inaccessible in Turing Pi 2 chassis).

### Boot File Deployment
BalenaOS deploys boot files via `BALENA_BOOT_PARTITION_FILES` mechanism (NOT rootfs packages):

```bitbake
# In balena-image.inc
BALENA_BOOT_PARTITION_FILES:append = " \
    idbloader.img:/ \
    u-boot.itb:/ \
    fitImage:/boot/fitImage \
    rk3588-turing-rk1.dtb:/boot/rk3588-turing-rk1.dtb \
    extlinux.conf:/boot/extlinux/extlinux.conf \
"
```

Files are deployed directly from `build/tmp/deploy/images/turing-rk1/` to the boot partition during image creation (see [BALENA-KERNEL-DEPLOYMENT.md](BALENA-KERNEL-DEPLOYMENT.md) for details).

### Device Tree
- **Source**: Armbian linux-rockchip kernel (rk-6.1-rkr6.1 branch)
- **Files**: 
  - `rk3588-turing-rk1.dts` - Main device tree
  - `rk3588-turing-rk1.dtsi` - Hardware definitions (764 lines)
- **Peripherals**: USB 2/3, PCIe Gen3, Dual GMAC, NPU, VPU, HDMI, audio

## Development

### Build Requirements
- **Docker** (recommended) or native Ubuntu 22.04
- **Disk Space**: 100GB minimum
- **Memory**: 16GB RAM minimum
- **Time**: 2-4 hours for clean build

### Building Without Docker
```bash
# Install dependencies (Ubuntu 22.04)
sudo apt-get install gawk wget git diffstat unzip texinfo \
  gcc build-essential chrpath socat cpio python3 python3-pip \
  python3-pexpect xz-utils debianutils iputils-ping python3-git \
  python3-jinja2 libegl1-mesa libsdl1.2-dev xterm

# Clone and build
git clone <this-repo>
cd rockchip-rk3588-rk1-yocto-balena
./setup-balena.sh  # Initialize layers
make image         # Build
```

### Modifying Configuration
- **Machine config**: `layers/meta-balena-turing-rk1/conf/machine/turing-rk1.conf`
- **U-Boot**: `layers/meta-balena-turing-rk1/recipes-bsp/u-boot/`
- **Kernel**: `layers/meta-balena-turing-rk1/recipes-kernel/linux/`
- **Image**: `layers/meta-balena-turing-rk1/recipes-core/images/balena-image.inc`

### Clean Build
```bash
make image  # Handles cleanup automatically via docker-build.sh
```

## Verification

### Check Image Structure
```bash
# List partitions
fdisk -l build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img

# Mount and verify boot partition (partition 3)
sudo losetup -fP build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img
sudo mount /dev/loopXp3 /mnt
ls -lh /mnt/boot/  # Should show fitImage, DTB, extlinux/
sudo umount /mnt
sudo losetup -d /dev/loopX
```

### Serial Console Access
Connect to **UART9** via Turing Pi 2 BMC or chassis USB console:
```bash
# Via screen
screen /dev/ttyUSB0 115200

# Via minicom
minicom -D /dev/ttyUSB0 -b 115200
```

Expected output:
1. DDR initialization messages
2. ATF BL31 messages
3. U-Boot banner and boot menu
4. Kernel boot messages
5. BalenaOS init and login prompt

## Troubleshooting

### No Console Output
- **Check**: UART9 connection (not UART2!)
- **Verify**: Using correct DDR blob with UART9 support
- **Test**: U-Boot `CONFIG_DEBUG_UART_BASE=0xfeb90000`

### Boot Hangs at U-Boot
- **Check**: Boot partition mounted correctly
- **Verify**: `fitImage` and DTB exist in `/boot/`
- **Test**: Manually load kernel from U-Boot prompt

### Kernel Panic
- **Check**: Device tree compatible string
- **Verify**: Console configuration in kernel cmdline
- **Test**: Try different DTB or kernel version

### Empty Rootfs
- **Normal**: BalenaOS uses overlay2 layers, not traditional rootfs
- **Check**: `/balena/overlay2/<hash>/diff/` should contain OS files
- **Verify**: `init` binary exists in volume

## References

- **BalenaOS Documentation**: https://www.balena.io/docs/
- **Turing RK1**: https://turingpi.com/product/turing-rk1/
- **Turing Pi 2**: https://docs.turingpi.com/
- **Armbian RK3588**: https://github.com/armbian/linux-rockchip
- **Yocto Project**: https://docs.yoctoproject.org/
- **meta-balena**: https://github.com/balena-os/meta-balena
- **meta-rockchip**: https://github.com/radxa/meta-rockchip

## License

See individual layer licenses. Most components are MIT or Apache-2.0.

## Contributing

This is a custom build for the Turing RK1. For BalenaOS core changes, contribute to meta-balena upstream.
